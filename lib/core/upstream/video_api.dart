import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_models.dart';
import '../models/source_kind.dart';
import '../models/video_source.dart';
import '../parser/maccms_parser.dart';

/// 分集播放地址解析结果。
class PlayResolution {
  const PlayResolution({
    required this.url,
    this.headers = const {},
    this.needsParse = false,
  });

  final String url;
  final Map<String, String> headers;

  /// 服务端标记该线路需要第三方解析（TVBox 的 parse/jx）。
  final bool needsParse;
}

/// 影视源上游接口。
///
/// `SourceKind.maccms` 走 MacCMS V10 JSON 接口；`SourceKind.ds` 走 drpy-node 的
/// T4 接口（`/api/<名称>`），规则由服务端执行，播放地址需要额外解析一次。
class VideoApi {
  VideoApi({
    http.Client? client,
    MacCmsParser? parser,
    Map<String, String> headers = const {},
  }) : _headers = Map.unmodifiable(headers),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _parser = parser ?? MacCmsParser();

  final Map<String, String> _headers;
  final http.Client _client;
  final bool _ownsClient;
  final MacCmsParser _parser;

  Future<List<MediaItem>> search(
    VideoSource source,
    String keyword,
    int page,
  ) async {
    final json = await _get(source, _searchQuery(source, keyword, page));
    return _parser.parseMediaList(json, source);
  }

  /// 分类列表分页结果，含上游返回的总页数。
  Future<MediaPage> categoryPage(
    VideoSource source,
    String categoryId,
    int page, {
    Map<String, String> filters = const {},
  }) async {
    final json = await _get(
      source,
      _categoryQuery(source, categoryId, page, filters),
    );
    return _parser.parseMediaPage(json, source);
  }

  Future<List<MediaItem>> recentVideos(
    VideoSource source, {
    required int hours,
    int page = 1,
  }) async {
    final json = await _get(source, _recentQuery(source, hours, page));
    return _parser.parseMediaList(json, source);
  }

  Future<List<MediaItem>> latestVideos(
    VideoSource source, {
    int page = 1,
  }) async {
    final json = await _get(source, _latestQuery(source, page));
    return _parser.parseMediaList(json, source);
  }

  Future<List<SourceCategory>> categories(VideoSource source) async {
    final json = await _get(source, _categoriesQuery(source));
    return _parser.parseCategories(json, source);
  }

  Future<MediaDetail?> detail(VideoSource source, String mediaId) async {
    final detail = _parser.parseDetail(
      await _get(source, _detailQuery(source, mediaId)),
      source,
      fallbackId: mediaId,
    );
    if (detail != null || source.kind == SourceKind.ds) {
      return detail;
    }
    // 少数 MacCMS 站点只实现了 ac=detail。
    return _parser.parseDetail(
      await _get(source, {'ac': 'detail', 'ids': mediaId}),
      source,
      fallbackId: mediaId,
    );
  }

  /// 解析分集播放地址。
  ///
  /// DS 源的分集值是服务端的 play id，需要再请求一次换取真实地址与请求头。
  Future<PlayResolution> resolvePlay(
    VideoSource source, {
    required PlayLine line,
    required Episode episode,
  }) async {
    if (source.kind != SourceKind.ds) {
      return PlayResolution(url: episode.url);
    }
    final json = await _get(source, {
      'play': episode.url,
      if (line.flag.isNotEmpty) 'flag': line.flag,
    });
    final url = _playUrl(json['url']);
    if (url == null) {
      throw Exception('${source.name}：${_playFailureMessage(json)}');
    }
    return PlayResolution(
      url: url,
      headers: _stringMap(json['headers'] ?? json['header']),
      needsParse: _needsParser(json) && !_isDirectMediaUrl(url),
    );
  }

  Map<String, String> _searchQuery(
    VideoSource source,
    String keyword,
    int page,
  ) => switch (source.kind) {
    SourceKind.maccms => {'ac': 'videolist', 'wd': keyword, 'pg': '$page'},
    SourceKind.ds => {'wd': keyword, 'pg': '$page'},
  };

  Map<String, String> _categoryQuery(
    VideoSource source,
    String categoryId,
    int page,
    Map<String, String> filters,
  ) => switch (source.kind) {
    SourceKind.maccms => {'ac': 'videolist', 't': categoryId, 'pg': '$page'},
    SourceKind.ds => {
      'ac': 'list',
      't': categoryId,
      'pg': '$page',
      // drpy-node 的筛选条件是 base64 的 JSON（`ext`）。
      if (filters.isNotEmpty) 'ext': _encodeFilters(filters),
    },
  };

  String _encodeFilters(Map<String, String> filters) =>
      base64.encode(utf8.encode(jsonEncode(filters)));

  // DS 没有独立的「最近/最新」接口，首页数据即推荐数据。
  Map<String, String> _recentQuery(VideoSource source, int hours, int page) =>
      switch (source.kind) {
        SourceKind.maccms => {'ac': 'videolist', 'h': '$hours', 'pg': '$page'},
        SourceKind.ds => const {'filter': '1'},
      };

  Map<String, String> _latestQuery(VideoSource source, int page) =>
      switch (source.kind) {
        SourceKind.maccms => {'ac': 'videolist', 'pg': '$page'},
        SourceKind.ds => const {'filter': '1'},
      };

  Map<String, String> _categoriesQuery(VideoSource source) =>
      switch (source.kind) {
        SourceKind.maccms => const {'ac': 'list'},
        SourceKind.ds => const {'filter': '1'},
      };

  Map<String, String> _detailQuery(VideoSource source, String mediaId) =>
      switch (source.kind) {
        SourceKind.maccms => {'ac': 'videolist', 'ids': mediaId},
        SourceKind.ds => {'ac': 'detail', 'ids': mediaId},
      };

  Future<Map<String, Object?>> _get(
    VideoSource source,
    Map<String, String> query,
  ) async {
    final uri = buildSourceUri(source, query);
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout(source));
    if (response.statusCode != 200) {
      throw Exception(
        '${source.name} 请求失败：HTTP ${response.statusCode}'
        '${_errorSuffix(response.bodyBytes)}',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final map = switch (decoded) {
      final Map<String, Object?> value => value,
      // DS 详情接口可能直接返回数组。
      final List<Object?> value => {'list': value},
      _ => throw Exception('${source.name} 响应不是 JSON 对象'),
    };
    final error = _text(map['error']);
    if (error.isNotEmpty) {
      throw Exception('${source.name}：$error');
    }
    final code = map['code'];
    if (code != null &&
        !const [1, 200, '1', '200'].contains(code) &&
        _text(map['msg']).isNotEmpty) {
      throw Exception('${source.name}：${_text(map['msg'])}');
    }
    return map;
  }

  Duration _timeout(VideoSource source) => source.kind == SourceKind.ds
      ? const Duration(seconds: 30)
      : const Duration(seconds: 10);

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// 拼接上游请求地址：保留 api_url 上的查询（pwd/do 等），再叠加 extend 与本次参数。
Uri buildSourceUri(VideoSource source, Map<String, String> query) {
  final base = parseSourceUri(source.apiUrl);
  final params = <String, String>{
    ...base.queryParameters,
    if (source.extend.isNotEmpty) 'extend': source.extend,
    ...query,
  };
  if (params.isEmpty) {
    return base;
  }
  return base.replace(queryParameters: params);
}

/// 解析源地址；站点名可能含 `[` `]` 等字符，解析失败时转义后重试。
Uri parseSourceUri(String url) {
  try {
    return Uri.parse(url);
  } on FormatException {
    final index = url.indexOf('?');
    final path = index < 0 ? url : url.substring(0, index);
    final query = index < 0 ? '' : url.substring(index);
    return Uri.parse(
      path.replaceAll('[', '%5B').replaceAll(']', '%5D') + query,
    );
  }
}

bool _needsParser(Map<String, Object?> json) {
  for (final key in const ['parse', 'jx']) {
    final value = json[key];
    if (value == true || value == 1 || value == '1') {
      return true;
    }
  }
  return false;
}

/// 非 200 响应里服务端给出的原因（drpy-node 用 `{error: ...}`）。
///
/// 解析不出来时返回空串，调用方只报 HTTP 状态码。
String _errorSuffix(List<int> bodyBytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map) {
      return '';
    }
    final message = _text(decoded['error'] ?? decoded['msg']);
    if (message.isEmpty) {
      return '';
    }
    final trimmed = message.length > 160
        ? '${message.substring(0, 160)}…'
        : message;
    return '：$trimmed';
  } catch (_) {
    return '';
  }
}

/// `play` 接口没有给出可播放地址时的提示文案。
String _playFailureMessage(Map<String, Object?> json) {
  if (_needsPanAccount(json['url'])) {
    return '该线路需要网盘账号解析，无法直接播放，请切换其他线路';
  }
  final message = _text(json['msg']);
  if (message.isNotEmpty) {
    return message;
  }
  if (_needsParser(json)) {
    return '服务端要求第三方解析但未返回直链，可切换其他线路';
  }
  return '未返回有效播放地址';
}

/// `play` 接口的播放地址。
///
/// 网盘类源返回的是 `[名称, 地址, 名称, 地址]` 数组，且常附带一条
/// `http://127.0.0.1:<端口>/` 的本机代理地址（依赖电脑端服务，盒子上不可用），
/// 这里取第一条可直连的地址，并优先选择带媒体扩展名的。
String? _playUrl(Object? value) {
  final candidates = switch (value) {
    final String item => <String>[item],
    final List<Object?> items => items.whereType<String>().toList(),
    _ => const <String>[],
  };
  String? fallback;
  for (final candidate in candidates) {
    final url = _cleanPlayUrl(candidate);
    if (url == null) {
      continue;
    }
    if (_isDirectMediaUrl(url)) {
      return url;
    }
    fallback ??= url;
  }
  return fallback;
}

/// `play` 返回了网盘分享链接（`push://`）时，客户端无法直接播放。
///
/// 这类线路依赖服务端的网盘 SDK / 会员账号解析，只能换同影片的直链线路。
bool _needsPanAccount(Object? value) {
  final candidates = switch (value) {
    final String item => <String>[item],
    final List<Object?> items => items.whereType<String>(),
    _ => const <String>[],
  };
  return candidates.any((item) => item.trim().startsWith('push://'));
}

/// 去掉 TVBox 追加在地址尾部的 `#isVideo=true##threads=10#` 标记，
/// 并过滤只能在电脑上使用的本机代理地址。
String? _cleanPlayUrl(String value) {
  var text = value.trim();
  final marker = text.indexOf('#');
  if (marker > 0) {
    text = text.substring(0, marker);
  }
  if (!_isHttpUrl(text)) {
    return null;
  }
  final host = Uri.tryParse(text)?.host ?? '';
  if (const [
    '127.0.0.1',
    'localhost',
    '0.0.0.0',
    '::1',
    '[::1]',
  ].contains(host)) {
    return null;
  }
  return text;
}

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

bool _isDirectMediaUrl(String value) => RegExp(
  r'\.(m3u8|mp4|m4a|mp3|flv|mkv|mov|avi|wmv|ts)(\?|$)',
).hasMatch(value);

String _text(Object? value) => value?.toString().trim() ?? '';

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  final result = <String, String>{};
  value.forEach((key, item) {
    final text = _text(item);
    if (text.isNotEmpty) {
      result[key.toString()] = text;
    }
  });
  return result;
}
