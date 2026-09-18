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
          );
        })
        .whereType<SourceCategory>()
        .toList();
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

  MediaDetail? parseDetail(Map<String, Object?> json, VideoSource source) {
    for (final item in _list(json)) {
      final media = _mediaItem(item, source);
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

  MediaItem? _mediaItem(Map item, VideoSource source) {
    final id = _string(item['vod_id'] ?? item['id']);
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
