import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/media_models.dart';
import '../../core/models/video_source.dart';
import '../../data/repositories/app_providers.dart';
import '../../ui/theme/app_system_ui.dart';
import '../../ui/tv/tv_mode.dart';
import '../../ui/widgets/poster_card.dart';
import '../../ui/widgets/state_views.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({
    super.key,
    required this.sourceId,
    required this.categoryId,
  });

  final String sourceId;
  final String categoryId;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  /// 距底部多远开始预取下一页。
  static const _prefetchExtent = 600.0;

  final _scrollController = ScrollController();
  final _items = <MediaItem>[];
  late String _categoryId = widget.categoryId;
  VideoSource? _source;
  Map<String, String> _filters = const {};
  int _page = 0;
  int _token = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTvNavigation(context);
    final categories = ref
        .watch(sourceCategoriesProvider(widget.sourceId))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <SourceCategory>[],
        );
    final current = _categoryOf(categories);
    return SystemUiRestorer(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current?.name ?? '分类'),
              if (current != null)
                Text(
                  current.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        body: SafeArea(top: false, child: _body(tv, categories)),
      ),
    );
  }

  Widget _body(bool tv, List<SourceCategory> categories) {
    final currentFilters =
        _categoryOf(categories)?.filters ?? const <SourceFilter>[];
    if (_loading) {
      return const LoadingState(message: '正在加载分类...');
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () => unawaited(_loadFirstPage()),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: '暂无内容',
        message: '当前分类没有返回视频。',
      );
    }
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: _CategoryChips(
              categories: categories,
              selectedId: _categoryId,
              onSelected: _switchCategory,
            ),
          ),
        if (currentFilters.isNotEmpty)
          SliverToBoxAdapter(
            child: _FilterBar(
              filters: currentFilters,
              selected: _filters,
              onSelected: _selectFilter,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: tv ? tvPosterGridDelegate : densePosterGridDelegate,
            itemBuilder: (context, index) {
              final item = _items[index];
              return PosterCard(
                item: item,
                autofocus: tv && index == 0,
                onTap: () =>
                    context.push(SkyRoutes.detail(item.sourceId, item.id)),
              );
            },
            itemCount: _items.length,
          ),
        ),
        SliverToBoxAdapter(
          child: _CategoryFooter(
            loading: _loadingMore,
            hasMore: _hasMore,
            error: _moreError,
            nextPage: _page + 1,
            tv: tv,
            total: _items.length,
            onLoadMore: () => unawaited(_loadMore()),
          ),
        ),
      ],
    );
  }

  SourceCategory? _categoryOf(List<SourceCategory> categories) {
    for (final category in categories) {
      if (category.id == _categoryId) {
        return category;
      }
    }
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _prefetchExtent) {
      unawaited(_loadMore());
    }
  }

  void _switchCategory(String categoryId) {
    if (categoryId == _categoryId) {
      return;
    }
    _categoryId = categoryId;
    _filters = const {};
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(_loadFirstPage());
  }

  void _selectFilter(SourceFilter filter, String value) {
    if ((_filters[filter.key] ?? '') == value) {
      return;
    }
    setState(() {
      final next = Map<String, String>.from(_filters);
      if (value.isEmpty) {
        next.remove(filter.key);
      } else {
        next[filter.key] = value;
      }
      _filters = next;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(_loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    try {
      final result = await _fetchPage(1);
      if (!mounted || token != _token) {
        return;
      }
      setState(() {
        _loading = false;
        _items.addAll(result.items);
        _page = 1;
        _hasMore = result.hasMoreAfter(1) && result.items.isNotEmpty;
      });
    } catch (error) {
      if (!mounted || token != _token) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }
    final token = _token;
    final next = _page + 1;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final result = await _fetchPage(next);
      if (!mounted || token != _token) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _items.addAll(result.items);
        _page = next;
        _hasMore = result.hasMoreAfter(next) && result.items.isNotEmpty;
      });
    } catch (error) {
      if (!mounted || token != _token) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _moreError = error.toString();
      });
    }
  }

  Future<MediaPage> _fetchPage(int page) async {
    final source = _source ??= await _resolveSource();
    final repo = await ref.read(mediaRepositoryProvider.future);
    return repo.categoryPage(
      source,
      _categoryId,
      page: page,
      filters: _filters,
    );
  }

  Future<VideoSource> _resolveSource() async {
    final repo = await ref.read(sourceRepositoryProvider.future);
    final source = repo.findById(widget.sourceId);
    if (source == null) {
      throw Exception('影视源不存在');
    }
    return source;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<SourceFilter> filters;
  final Map<String, String> selected;
  final void Function(SourceFilter filter, String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final filter in filters)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: Text(
                    filter.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final option in filter.options)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.name),
                      selected: (selected[filter.key] ?? '') == option.value,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 12),
                      onSelected: (_) => onSelected(filter, option.value),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<SourceCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ChoiceChip(
            label: Text(category.name),
            selected: category.id == selectedId,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryFooter extends StatelessWidget {
  const _CategoryFooter({
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.nextPage,
    required this.tv,
    required this.total,
    required this.onLoadMore,
  });

  final bool loading;
  final bool hasMore;
  final String? error;
  final int nextPage;
  final bool tv;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final message = error;
    if (message != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          children: [
            InlineState(
              icon: Icons.error_outline_rounded,
              title: '第 $nextPage 页加载失败',
              message: message,
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Center(
          child: Text(
            '已经到底了，共 $total 部',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Center(
        child: Focus(
          canRequestFocus: false,
          // 电视：焦点走到「加载更多」即自动翻页，不必再按确认键。
          onFocusChange: (focused) {
            if (focused && tv) {
              onLoadMore();
            }
          },
          child: OutlinedButton.icon(
            onPressed: loading ? null : onLoadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(
              loading ? '正在加载第 $nextPage 页...' : '加载更多（第 $nextPage 页）',
            ),
          ),
        ),
      ),
    );
  }
}
