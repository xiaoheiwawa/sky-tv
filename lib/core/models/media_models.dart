class SourceSubscription {
  const SourceSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
    this.contentHash = '',
    this.lastCheckedAt,
    this.lastUpdatedAt,
  });

  final String id;
  final String name;
  final String url;
  final bool enabled;
  final String contentHash;
  final DateTime? lastCheckedAt;
  final DateTime? lastUpdatedAt;
}

class SourceCategory {
  const SourceCategory({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.name,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final String name;
}

class CategoryPreviewRow {
  const CategoryPreviewRow({required this.category, required this.items});

  final SourceCategory category;
  final List<MediaItem> items;
}

/// 分页列表结果：分类、搜索等接口按页返回。
class MediaPage {
  const MediaPage({required this.items, this.pageCount});

  final List<MediaItem> items;

  /// 上游返回的总页数；上游未提供时为 null，只能按本页是否有数据判断。
  final int? pageCount;

  /// [page] 页之后是否还有内容。
  bool hasMoreAfter(int page) {
    final count = pageCount;
    return count == null ? items.isNotEmpty : page < count;
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    this.poster,
    this.year,
    this.category,
    this.description,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final String title;
  final String? poster;
  final String? year;
  final String? category;
  final String? description;
}

class MediaDetail extends MediaItem {
  const MediaDetail({
    required super.id,
    required super.sourceId,
    required super.sourceName,
    required super.title,
    super.poster,
    super.year,
    super.category,
    super.description,
    required this.playLines,
  });

  final List<PlayLine> playLines;
}

class PlayLine {
  const PlayLine({required this.name, required this.episodes, this.flag = ''});

  final String name;

  /// 线路原始标识，DS 源播放时作为 `flag` 回传。
  final String flag;
  final List<Episode> episodes;
}

class Episode {
  const Episode({required this.title, required this.url});

  final String title;
  final String url;
}

class WatchRecord {
  const WatchRecord({
    required this.sourceId,
    required this.mediaId,
    required this.sourceName,
    required this.title,
    required this.updatedAt,
    this.poster,
    this.lineIndex = 0,
    this.episodeIndex = 0,
    this.positionMs = 0,
    this.durationMs = 0,
  });

  final String sourceId;
  final String mediaId;
  final String sourceName;
  final String title;
  final String? poster;
  final int lineIndex;
  final int episodeIndex;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
}
