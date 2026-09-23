import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/media_models.dart';
import '../../data/repositories/app_providers.dart';
import 'poster_fallback.dart';

const densePosterGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 124,
  childAspectRatio: 0.58,
  crossAxisSpacing: 8,
  mainAxisSpacing: 10,
);

/// 电视/大屏：海报更大，遥控器隔空操作也能看清焦点。
const tvPosterGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 208,
  childAspectRatio: 0.58,
  crossAxisSpacing: 14,
  mainAxisSpacing: 18,
);

/// 电视焦点框：留出 3px 内边距画描边，聚焦时描边高亮并轻微放大。
class TvFocusRing extends StatelessWidget {
  const TvFocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.radius = 14,
  });

  final bool focused;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AnimatedScale(
        scale: focused ? 1.05 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: focused ? scheme.primary : Colors.transparent,
              width: 2.4,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

enum PosterMetaMode { compact, withSource }

String? mediaMetaLine(
  MediaItem item, {
  required PosterMetaMode mode,
  bool omitCategory = false,
}) {
  return switch (mode) {
    PosterMetaMode.compact => _joinMeta([
      item.year,
      if (!omitCategory) item.category,
    ]),
    PosterMetaMode.withSource => _joinMeta([
      item.year,
      if (!omitCategory) item.category,
      item.sourceName,
    ]),
  };
}

String? _joinMeta(List<String?> parts) {
  final text = parts
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .join(' · ');
  return text.isEmpty ? null : text;
}

int posterMemCacheFor(double displayWidth, {int max = 720}) {
  final ratio =
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  return (displayWidth * ratio).ceil().clamp(88, max);
}

class PosterImage extends ConsumerWidget {
  const PosterImage({
    super.key,
    required this.url,
    required this.memCacheWidth,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final int memCacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) {
      return const PosterFallback();
    }
    final headers = ref
        .watch(requestHeadersProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <String, String>{},
        );
    // 只约束宽度，保比例解码，避免 exact 双约束发糊。
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      httpHeaders: headers.isEmpty ? null : headers,
      memCacheWidth: memCacheWidth,
      placeholder: (_, _) => const PosterFallback(),
      errorWidget: (_, _, _) => const PosterFallback(),
    );
  }
}

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.metaMode = PosterMetaMode.compact,
    this.autofocus = false,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final PosterMetaMode metaMode;

  /// 电视进入页面时把焦点放在首张海报上。
  final bool autofocus;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 160.0;
        final category = widget.item.category?.trim();
        final showCategoryBadge = category != null && category.isNotEmpty;
        final remarksText = widget.item.remarks?.trim();
        final remarks = remarksText == null || remarksText.isEmpty
            ? null
            : remarksText;
        final meta = mediaMetaLine(
          widget.item,
          mode: widget.metaMode,
          omitCategory: showCategoryBadge,
        );
        return TvFocusRing(
          focused: _focused,
          child: InkWell(
            autofocus: widget.autofocus,
            onFocusChange: (value) => setState(() => _focused = value),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(
                      url: widget.item.poster,
                      memCacheWidth: posterMemCacheFor(width),
                    ),
                    if (showCategoryBadge)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _PosterBadge(label: category),
                      ),
                    if (remarks != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _PosterBadge(label: remarks),
                      ),
                    _PosterCaption(title: widget.item.title, meta: meta),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ContinueWatchCard extends StatefulWidget {
  const ContinueWatchCard({
    super.key,
    required this.record,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
  });

  final WatchRecord record;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  State<ContinueWatchCard> createState() => _ContinueWatchCardState();
}

class _ContinueWatchCardState extends State<ContinueWatchCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 118.0;
        final record = widget.record;
        final progress = record.durationMs <= 0
            ? 0.0
            : (record.positionMs / record.durationMs).clamp(0.0, 1.0);
        return TvFocusRing(
          focused: _focused,
          child: InkWell(
            autofocus: widget.autofocus,
            onFocusChange: (value) => setState(() => _focused = value),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(
                      url: record.poster,
                      memCacheWidth: posterMemCacheFor(width),
                    ),
                    _PosterCaption(
                      title: record.title,
                      meta: '第 ${record.episodeIndex + 1} 集',
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 3,
                        backgroundColor: Colors.black38,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PosterBadge extends StatelessWidget {
  const _PosterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PosterCaption extends StatelessWidget {
  const _PosterCaption({required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 20, 8, meta == null ? 8 : 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (meta != null) ...[
                const SizedBox(height: 3),
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
