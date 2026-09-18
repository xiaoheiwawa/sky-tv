import 'dart:convert';

import '../models/parse_rule.dart';
import '../models/source_kind.dart';
import '../models/video_source.dart';

class SourceImportResult {
  const SourceImportResult({
    required this.sources,
    required this.errors,
    this.iptvSubscriptions = const [],
    this.parseRules = const [],
  });

  final List<VideoSource> sources;
  final List<String> errors;

  /// TVBox 配置里的直播订阅（`lives`）。
  final List<ImportedIptvSubscription> iptvSubscriptions;

  /// TVBox 配置里的解析服务（`parses`）。
  final List<ParseRule> parseRules;
}

class ImportedIptvSubscription {
  const ImportedIptvSubscription({required this.name, required this.url});

  final String name;
  final String url;
}

/// 导入影视源。
///
/// 支持 sky-tv 自身的 `[{name, api_url}]` / `{sources: []}` 以及 TVBox 配置
/// （`{sites: [], lives: []}`）；TVBox 里需要客户端执行规则的类型会被跳过并记录原因。
SourceImportResult importSourcesFromJson(String input) {
  final decoded = jsonDecode(input);
  final map = decoded is Map<String, Object?> ? decoded : null;
  final isTvBox = map?['sites'] is List<Object?>;
  final list = switch (decoded) {
    final List<Object?> value => value,
    final Map<String, Object?> value when value['sources'] is List<Object?> =>
      value['sources'] as List<Object?>,
    final Map<String, Object?> value when value['sites'] is List<Object?> =>
      value['sites'] as List<Object?>,
    _ => throw const FormatException('订阅源 JSON 必须是数组、sources 数组或 sites 数组'),
  };

  final sourcesById = <String, VideoSource>{};
  final errors = <String>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    try {
      if (item is! Map<String, Object?>) {
        throw const FormatException('源配置必须是对象');
      }
      final source = isTvBox
          ? _sourceFromTvBoxSite(item)
          : VideoSource.fromJson(item);
      sourcesById[source.sourceId] = source;
    } on FormatException catch (error) {
      errors.add('第 ${i + 1} 项：${error.message}');
    } catch (error) {
      errors.add('第 ${i + 1} 项：$error');
    }
  }
  return SourceImportResult(
    sources: sourcesById.values.toList(),
    errors: errors,
    iptvSubscriptions: isTvBox
        ? _subscriptionsFromTvBoxLives(map?['lives'])
        : const [],
    parseRules: isTvBox ? _parseRulesFromTvBox(map?['parses']) : const [],
  );
}

List<ParseRule> _parseRulesFromTvBox(Object? raw) {
  final list = switch (raw) {
    final List<Object?> value => value,
    final Map<String, Object?> value => <Object?>[value],
    _ => const <Object?>[],
  };
  final result = <ParseRule>[];
  final seen = <String>{};
  for (final item in list) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    try {
      final rule = ParseRule.fromJson(item);
      if (!rule.url.startsWith('http')) {
        continue;
      }
      if (seen.add(rule.id)) {
        result.add(rule);
      }
    } catch (_) {
      continue;
    }
  }
  return result;
}

VideoSource _sourceFromTvBoxSite(Map<String, Object?> site) {
  final name = _text(site['name'] ?? site['key']);
  if (name.isEmpty) {
    throw const FormatException('站点缺少 name/key');
  }
  final api = _text(site['api']);
  if (api.isEmpty) {
    throw FormatException('$name：缺少 api');
  }
  if (api.startsWith('csp_')) {
    throw FormatException('$name：spider 站点（csp_）需要客户端执行，暂不支持');
  }
  final type = _int(site['type']);
  if (type == 3) {
    throw FormatException('$name：type 3（JS 规则）需要客户端 JS 引擎，暂不支持');
  }
  final SourceKind kind;
  if (api.contains('api.php/provide/vod') || api.contains('/at/json')) {
    kind = SourceKind.maccms;
  } else if (api.contains('/api/')) {
    kind = SourceKind.ds;
  } else if (type == 0) {
    throw FormatException('$name：type 0（XML 接口）暂不支持');
  } else {
    throw FormatException('$name：暂不支持该接口类型');
  }
  return VideoSource.create(
    name: name,
    apiUrl: api,
    kind: kind,
    extend: _text(site['ext']),
  );
}

List<ImportedIptvSubscription> _subscriptionsFromTvBoxLives(Object? raw) {
  final list = switch (raw) {
    final List<Object?> value => value,
    final Map<String, Object?> value => <Object?>[value],
    _ => const <Object?>[],
  };
  final result = <ImportedIptvSubscription>[];
  final seen = <String>{};
  for (final item in list) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final url = _text(item['url']);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      continue;
    }
    if (!seen.add(url)) {
      continue;
    }
    final name = _text(item['name'] ?? item['key']);
    result.add(
      ImportedIptvSubscription(
        name: name.isEmpty ? _host(url) : name,
        url: url,
      ),
    );
  }
  return result;
}

String _host(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? url : host;
}

String _text(Object? value) => value?.toString().trim() ?? '';

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(_text(value));
}
