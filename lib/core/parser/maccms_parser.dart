import '../models/media_models.dart';
import '../models/source_kind.dart';
import '../models/video_source.dart';
import 'play_url_parser.dart';

class MacCmsParser {
  List<SourceCategory> parseCategories(
    Map<String, Object?> json,
    VideoSource source,
  ) {
    final raw = json['class'];
    if (raw is! List) {
      return const [];
    }
    final filters = parseFilters(json['filters']);
    // 服务端用 `*` 表示所有分类共用同一组筛选。
    final shared = filters['*'] ?? const <SourceFilter>[];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = _string(item['type_id'] ?? item['id']);
          final name = _string(item['type_name'] ?? item['name']);
          if (id.isEmpty || name.isEmpty) {
            return null;
          }
          return SourceCategory(
            id: id,
            sourceId: source.sourceId,
            sourceName: source.name,
            name: name,
            filters: filters[id] ?? shared,
          );
        })
        .whereType<SourceCategory>()
        .toList();
  }

  /// 解析 drpy-node 的二级筛选表（`filters`），按分类 ID 分组。
  ///
  /// 服务端可能返回 `{*: [...]}` 表示所有分类共用同一组筛选，
  /// 此时 [parseCategories] 会为每个分类回退到 `*`。
  Map<String, List<SourceFilter>> parseFilters(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, List<SourceFilter>>{};
    raw.forEach((key, value) {
      final filters = _filterGroups(value);
      if (filters.isNotEmpty) {
        result[key.toString()] = filters;
      }
    });
    return result;
  }

  List<SourceFilter> _filterGroups(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final groups = <SourceFilter>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final key = _string(item['key']);
      final options = <SourceFilterOption>[];
      final values = item['value'];
      if (values is List) {
        for (final option in values) {
          if (option is! Map) {
            continue;
          }
          final name = _string(option['n'] ?? option['name']);
          final value = _string(option['v'] ?? option['value']);
          if (name.isEmpty && value.isEmpty) {
            continue;
          }
          options.add(
            SourceFilterOption(name: name.isEmpty ? value : name, value: value),
          );
        }
      }
      if (key.isEmpty || options.isEmpty) {
        continue;
      }
      groups.add(
        SourceFilter(
          key: key,
          name: _string(item['name']).isEmpty ? key : _string(item['name']),
          options: options,
        ),
      );
    }
    return groups;
  }

  List<MediaItem> parseMediaList(
    Map<String, Object?> json,
    VideoSource source,
  ) {
    final raw = _list(json);
    if (raw.isEmpty) {
      return const [];
    }
    final items = raw
        .map((item) => _mediaItem(item, source))
        .whereType<MediaItem>()
        .toList();
    if (items.isNotEmpty) {
      return items;
    }
    if (raw.every(_isPlaceholder)) {
      throw const FormatException('上游返回「无数据」占位，该源当前不可用');
    }
    throw const FormatException('MacCMS 响应缺少 vod_id 或 vod_name');
  }

  /// 解析分页列表，并读取上游的总页数（MacCMS 与 drpy 都返回 `pagecount`）。
  ///
  /// 上游不给总页数时 [MediaPage.pageCount] 为 null，调用方只能按本页是否有
  /// 数据判断后面还有没有内容。
  MediaPage parseMediaPage(Map<String, Object?> json, VideoSource source) {
    try {
      return MediaPage(
        items: parseMediaList(json, source),
        pageCount: _pageCount(json),
      );
    } on FormatException catch (error) {
      // 翻页到「无数据」占位页时视为没有更多内容，优雅停在上一页；
      // 而不是把整页判为源不可用中断翻页（参照 webhtv 空列表优雅停止策略）。
      if (error.message.contains('无数据')) {
        return MediaPage(items: const [], pageCount: _pageCount(json));
      }
      rethrow;
    }
  }

  int? _pageCount(Map<String, Object?> json) {
    for (final key in const ['pagecount', 'page_count', 'totalpage']) {
      final value = int.tryParse(_string(json[key]));
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }

  /// 解析详情。
  ///
  /// 网盘类（netdisk）源的详情响应通常不返回 `vod_id`，只回 `vod_name` 等内容，
  /// 这时用请求时使用的 [fallbackId] 兜底，否则详情会被判为无效。
  MediaDetail? parseDetail(
    Map<String, Object?> json,
    VideoSource source, {
    String? fallbackId,
  }) {
    for (final item in _list(json)) {
      final media = _mediaItem(item, source, fallbackId: fallbackId);
      if (media == null) {
        continue;
      }
      return MediaDetail(
        id: media.id,
        sourceId: media.sourceId,
        sourceName: media.sourceName,
        title: media.title,
        poster: media.poster,
        year: media.year,
        category: media.category,
        description: media.description,
        remarks: media.remarks,
        playLines: parsePlayLines(
          _optionalString(item['vod_play_from']),
          _optionalString(item['vod_play_url']),
          allowPlayId: source.kind == SourceKind.ds,
        ),
      );
    }
    return null;
  }

  List<Map> _list(Map<String, Object?> json) {
    final raw = json['list'];
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map>().toList();
  }

  MediaItem? _mediaItem(Map item, VideoSource source, {String? fallbackId}) {
    var id = _string(item['vod_id'] ?? item['id']);
    if (id.isEmpty) {
      id = fallbackId ?? '';
    }
    final title = _string(item['vod_name'] ?? item['name']);
    if (id.isEmpty || title.isEmpty || _isPlaceholder(item)) {
      return null;
    }
    return MediaItem(
      id: id,
      sourceId: source.sourceId,
      sourceName: source.name,
      title: title,
      poster: _optionalString(item['vod_pic']),
      year: _optionalString(item['vod_year']),
      category: _optionalString(item['type_name']),
      description: _cleanHtml(_optionalString(item['vod_content'])),
      remarks: _optionalString(item['vod_remarks']),
    );
  }

  /// drpy 系列规则在上游无数据时会返回占位条目，避免被当成正常影片。
  bool _isPlaceholder(Map item) {
    final id = _string(item['vod_id'] ?? item['id']);
    final title = _string(item['vod_name'] ?? item['name']);
    return id == 'no_data' || title.contains('防无限请求');
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _cleanHtml(String? value) {
    if (value == null) {
      return null;
    }
    return value.replaceAll(RegExp('<[^>]*>'), '').trim();
  }
}
