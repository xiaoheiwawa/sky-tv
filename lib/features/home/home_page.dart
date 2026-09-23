import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/media_models.dart';
import '../../data/repositories/app_providers.dart';
import '../../ui/widgets/app_dialogs.dart';
import '../../ui/widgets/app_logo.dart';
import '../../ui/widgets/home_focus_carousel.dart';

import '../../ui/widgets/poster_row.dart';
import '../../ui/widgets/state_views.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            onPressed: () => context.push('/home/edit'),
            icon: const Icon(Icons.edit_rounded),
            tooltip: '推荐位编辑',
          ),
          IconButton(
            onPressed: () => context.go(SkyRoutes.search()),
            icon: const Icon(Icons.search_rounded),
            tooltip: '搜索',
          ),
        ],
      ),
      body: data.when(
        skipLoadingOnReload: true,
        data: (home) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDataProvider);
            ref.invalidate(homeFeedProvider);
          },
          child: ListView(
            children: [
              const _HomeDiscover(),
              const _DoubanSection(),
              const _QuickAccessRow(),
              if (home.recentSearches.isNotEmpty)
                _RecentSearches(keywords: home.recentSearches),
              SectionHeader(
                title: '继续观看',
                action: home.records.isEmpty
                    ? TextButton(
                        onPressed: () => context.go(SkyRoutes.search()),
                        child: const Text('找片'),
                      )
                    : null,
              ),
              if (home.records.isEmpty)
                const SizedBox(
                  height: 160,
                  child: EmptyState(
                    icon: Icons.play_circle_outline,
                    title: '还没有播放记录',
                    message: '搜索影片并播放后，会在这里继续观看。',
                    compact: true,
                  ),
                )
              else ...[
                ContinueWatchRow(
                  records: home.records,
                  onTap: (record) => context.push(
                    SkyRoutes.player(
                      record.sourceId,
                      record.mediaId,
                      lineIndex: record.lineIndex,
                      episodeIndex: record.episodeIndex,
                      resume: true,
                    ),
                  ),
                  onLongPress: (record) =>
                      unawaited(_removeWatchRecord(context, ref, record)),
                ),
                const SizedBox(height: 4),
              ],
              const SectionHeader(title: '我的收藏'),
              if (home.favorites.isEmpty)
                const SizedBox(
                  height: 140,
                  child: EmptyState(
                    icon: Icons.favorite_border,
                    title: '暂无收藏',
                    message: '喜欢的影片可以在详情页收藏。',
                    compact: true,
                  ),
                )
              else ...[
                PosterRow(
                  items: home.favorites,
                  onTap: (item) =>
                      context.push(SkyRoutes.detail(item.sourceId, item.id)),
                  onLongPress: (item) =>
                      unawaited(_removeFavorite(context, ref, item)),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        error: (error, _) => ErrorState(message: error.toString()),
        loading: () => const LoadingState(message: '正在读取本地数据...'),
      ),
    );
  }
}

Future<void> _removeWatchRecord(
  BuildContext context,
  WidgetRef ref,
  WatchRecord record,
) async {
  final confirmed = await confirmActionDialog(
    context,
    title: '移除续看',
    message: '从继续观看中移除「${record.title}」？',
    confirmText: '移除',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final repo = await ref.read(mediaRepositoryProvider.future);
  repo.deleteWatchRecord(record.sourceId, record.mediaId);
  ref.invalidate(homeDataProvider);
  ref.invalidate(homeFeedProvider);
}

Future<void> _removeFavorite(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final confirmed = await confirmActionDialog(
    context,
    title: '取消收藏',
    message: '取消收藏「${item.title}」？',
    confirmText: '取消收藏',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final repo = await ref.read(mediaRepositoryProvider.future);
  repo.toggleFavorite(item);
  ref.invalidate(homeDataProvider);
  ref.invalidate(homeFeedProvider);
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.keywords});

  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '最近搜索'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            itemCount: keywords.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final keyword = keywords[index];
              return ActionChip(
                label: Text(keyword),
                onPressed: () => context.go(SkyRoutes.search(keyword)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeDiscover extends ConsumerWidget {
  const _HomeDiscover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    final hasEnabled = sources.maybeWhen(
      data: (items) => items.any((source) => !source.disabled),
      orElse: () => false,
    );
    if (!hasEnabled) {
      return const SizedBox.shrink();
    }
    final feed = ref.watch(homeFeedProvider);
    return feed.when(
      skipLoadingOnReload: true,
      data: (homeFeed) {
        if (homeFeed.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            if (homeFeed.focus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: HomeFocusCarousel(
                  items: homeFeed.focus,
                  onTap: (item) =>
                      context.push(SkyRoutes.detail(item.sourceId, item.id)),
                ),
              ),
            if (homeFeed.recommend.isNotEmpty) ...[
              SectionHeader(
                title: '为你推荐',
                action: TextButton(
                  onPressed: () => context.go('/sources'),
                  child: const Text('更多'),
                ),
              ),
              PosterRow(
                items: homeFeed.recommend,
                onTap: (item) =>
                    context.push(SkyRoutes.detail(item.sourceId, item.id)),
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// 豆瓣榜单：横向滑动海报流，右侧可切换榜单类型。
/// 豆瓣榜单：横向滑动海报流，右侧可切换榜单类型。
/// 数据来自豆瓣公开 API，不依赖用户配置的影视源。
class _DoubanSection extends ConsumerStatefulWidget {
  const _DoubanSection();

  @override
  ConsumerState<_DoubanSection> createState() => _DoubanSectionState();
}

class _DoubanSectionState extends ConsumerState<_DoubanSection> {
  static const _tabs = ['一周口碑榜', '华语口碑榜', '全球口碑榜'];
  static const _tabKeys = ['weekly', 'chinese', 'global'];

  int _selectedTab = 0;
  List<_DoubanItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _fetchDoubanList(_tabKeys[_selectedTab]);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<_DoubanItem>> _fetchDoubanList(String type) async {
    // 豆瓣榜单 API（公开接口，无需 key）
    final urls = {
      'weekly':
          'https://m.douban.com/rexxar/api/v2/subject_collection/tv_weekly_best/items?start=0&count=10',
      'chinese':
          'https://m.douban.com/rexxar/api/v2/subject_collection/tv_chinese_best_weekly/items?start=0&count=10',
      'global':
          'https://m.douban.com/rexxar/api/v2/subject_collection/tv_global_best_weekly/items?start=0&count=10',
    };
    final url = urls[type] ?? urls['weekly']!;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );
      request.headers.set('Referer', 'https://m.douban.com/');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = json['subject_collection_items'] as List<dynamic>? ?? [];
      return items
          .map((e) => _DoubanItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } finally {
      client.close();
    }
  }

  void _onTabChanged(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '豆瓣榜单'),
        SizedBox(
          height: 210,
          child: Row(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          '加载失败',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    : _items.isEmpty
                    ? const Center(child: Text('暂无数据'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _DoubanCard(
                            item: item,
                            onTap: () {
                              // 跳转到搜索页搜索该片
                              context.go(SkyRoutes.search(item.title));
                            },
                          );
                        },
                      ),
              ),
              SizedBox(
                width: 72,
                child: ListView.builder(
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    return _DoubanTab(
                      label: _tabs[index],
                      selected: _selectedTab == index,
                      onTap: () => _onTabChanged(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DoubanItem {
  const _DoubanItem({
    required this.title,
    required this.cover,
    required this.rating,
    required this.year,
  });

  final String title;
  final String cover;
  final String rating;
  final String year;

  factory _DoubanItem.fromJson(Map<String, dynamic> json) {
    return _DoubanItem(
      title: json['title'] as String? ?? '',
      cover: json['cover']?['url'] as String? ?? '',
      rating: (json['rating']?['value'] as num?)?.toStringAsFixed(1) ?? '',
      year: json['year'] as String? ?? '',
    );
  }
}

class _DoubanCard extends StatelessWidget {
  const _DoubanCard({required this.item, required this.onTap});

  final _DoubanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.movie_rounded),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.rating.isNotEmpty)
            Text(
              '⭐ ${item.rating}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _DoubanTab extends StatelessWidget {
  const _DoubanTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 快捷入口：收藏 / 历史 / 本地视频 / 网盘登录。
class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  static const _items = [
    (Icons.favorite_rounded, '我的收藏', '/sources'),
    (Icons.history_rounded, '历史记录', '/sources'),
    (Icons.video_file_rounded, '本地视频', '/sources'),
    (Icons.cloud_rounded, '网盘登录', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          for (final (icon, label, route) in _items)
            Expanded(
              child: _QuickAccessItem(
                icon: icon,
                label: label,
                onTap: () => context.go(route),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

