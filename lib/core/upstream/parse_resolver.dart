import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parse_rule.dart';

/// 解析结果。
class ParseResult {
  const ParseResult({
    required this.url,
    required this.ruleName,
    this.headers = const {},
  });

  final String url;
  final String ruleName;
  final Map<String, String> headers;
}

/// 第三方解析服务调用器。
///
/// DS 源返回 `parse/jx = 1` 时，播放地址需要交给解析服务换成真实地址：
/// JSON 类解析直接从响应里取 `url`，网页类解析从 HTML/JS 里嗅探 m3u8 链接。
class ParseResolver {
  ParseResolver({http.Client? client, Map<String, String> headers = const {}})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _headers = Map.unmodifiable(headers);

  static const _timeout = Duration(seconds: 15);
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _headers;

  /// 依次尝试解析服务，全部失败时抛出带原因的异常。
  Future<ParseResult> resolve(String playUrl, List<ParseRule> rules) async {
    if (rules.isEmpty) {
      throw const FormatException('该线路需要第三方解析，请先导入带 parses 的配置');
    }
    final failures = <String>[];
    String? fallbackUrl;
    String? fallbackRule;
    for (final rule in rules) {
      try {
        final text = await _fetch(rule, playUrl);
        final url = rule.type == ParseRuleType.json
            ? _urlFromJson(text, rule.url)
            : _urlFromHtml(text, rule.url);
        if (url == null) {
          failures.add('${rule.name}：未解析出地址');
          continue;
        }
        if (_isMediaUrl(url)) {
          return ParseResult(
            url: url,
            ruleName: rule.name,
            headers: rule.header,
          );
        }
        fallbackUrl ??= url;
        fallbackRule ??= rule.name;
      } catch (error) {
        failures.add('${rule.name}：${_message(error)}');
      }
    }
    if (fallbackUrl != null) {
      return ParseResult(url: fallbackUrl, ruleName: fallbackRule!);
    }
    throw FormatException('解析失败：${failures.take(3).join('；')}');
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<String> _fetch(ParseRule rule, String playUrl) async {
    final uri = _buildUri(rule.url, playUrl);
    final response = await _client
        .get(uri, headers: {..._headers, ...rule.header})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}

/// 解析服务地址：支持 `{url}` 占位符，否则把地址拼在末尾。
Uri _buildUri(String ruleUrl, String playUrl) {
  final encoded = Uri.encodeComponent(playUrl);
  if (ruleUrl.contains('{url}')) {
    return Uri.parse(ruleUrl.replaceAll('{url}', encoded));
  }
  return Uri.parse('$ruleUrl$encoded');
}

/// 从 JSON 响应里找播放地址。
String? _urlFromJson(String text, String baseUrl) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return _urlFromHtml(text, baseUrl);
  }
  return _findUrl(decoded, baseUrl);
}

String? _findUrl(Object? data, String baseUrl, [int depth = 0]) {
  if (depth > 4) {
    return null;
  }
  if (data is String) {
    return _normalize(data, baseUrl);
  }
  if (data is List) {
    for (final item in data) {
      final url = _findUrl(item, baseUrl, depth + 1);
      if (url != null) {
        return url;
      }
    }
    return null;
  }
  if (data is! Map) {
    return null;
  }
  for (final key in const [
    'url',
    'playUrl',
    'video',
    'src',
    'data',
    'result',
  ]) {
    final url = _findUrl(data[key], baseUrl, depth + 1);
    if (url != null) {
      return url;
    }
  }
  return null;
}

/// 从 HTML/JS 文本里嗅探播放地址。
String? _urlFromHtml(String text, String baseUrl) {
  final normalized = text.replaceAll(r'\/', '/').replaceAll('&amp;', '&');
  final matches = RegExp(
    r'https?://[^\s<>\x22\x27\\]+',
  ).allMatches(normalized).map((match) => match.group(0)!).toList();
  for (final match in matches) {
    if (_isMediaUrl(match)) {
      return _normalize(match, baseUrl);
    }
  }
  return matches.isEmpty ? null : _normalize(matches.first, baseUrl);
}

String? _normalize(String value, String baseUrl) {
  final text = value.trim();
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }
  if (text.startsWith('//')) {
    return '${Uri.parse(baseUrl).scheme}:$text';
  }
  if (text.startsWith('/')) {
    final base = Uri.parse(baseUrl);
    return '${base.scheme}://${base.authority}$text';
  }
  return null;
}

bool _isMediaUrl(String value) => RegExp(
  r'\.(m3u8|mp4|m4a|mp3|flv|mkv|ts)(\?|#|$)',
  caseSensitive: false,
).hasMatch(value);

String _message(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
