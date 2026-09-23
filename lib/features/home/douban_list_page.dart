import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';

/// 豆瓣榜单列表页：完整榜单展示，支持分类切换和分页加载。
class DoubanListPage extends StatefulWidget {
  const DoubanListPage({super.key, this.initialTag = '热门'});

  final String initialTag;

  @override
  State<DoubanListPage> createState() => _DoubanListPageState();
}

class _DoubanListPageState extends State<DoubanListPage> {
  static const _tabs = ['热门电影', '热门电视剧'];
  static const _tabTags = ['热门', '热门'];
  static const _tabTypes = ['movie', 'tv'];

  int _selectedTab = 0;
  List<_DoubanItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _pageStart = 0;
  static const _pageLimit = 20;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTag == '热门电视剧' ? 1 : 0;
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _pageStart = 0;
      _hasMore = true;
    });
    await _fetchData();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _fetchData(append: true);
  }

  Future<void> _fetchData({bool append = false}) async {
    try {
      final items = await _fetchDoubanList(
        _tabTags[_selectedTab],
        _tabTypes[_selectedTab],
        _pageStart,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _items.addAll(items);
        } else {
          _items = items;
        }
        _pageStart += _pageLimit;
        _hasMore = items.length >= _pageLimit;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<List<_DoubanItem>> _fetchDoubanList(
    String tag,
    String type,
    int start,
  ) async {
    final url =
        'https://movie.douban.com/j/search_subjects?type=$type&tag=${Uri.encodeComponent(tag)}&sort=recommend&page_limit=$_pageLimit&page_start=$start';
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );
      request.headers.set('Referer', 'https://movie.douban.com/');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = json['subjects'] as List<dynamic>? ?? [];
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('豆瓣榜单'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          // 顶部横向 Tab
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _DoubanTabChip(
                  label: _tabs[index],
                  selected: _selectedTab == index,
                  onTap: () => _onTabChanged(index),
                );
              },
            ),
          ),
          // 内容区
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '加载失败',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadData,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Center(child: Text('暂无数据'))
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final item = _items[index];
                      return _DoubanGridCard(
                        item: item,
                        onTap: () {
                          context.push(SkyRoutes.search(item.title));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DoubanItem {
  const _DoubanItem({
    required this.title,
    required this.cover,
    required this.rating,
    required this.id,
  });

  final String title;
  final String cover;
  final String rating;
  final String id;

  factory _DoubanItem.fromJson(Map<String, dynamic> json) {
    return _DoubanItem(
      title: json['title'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      rating: json['rate'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class _DoubanTabChip extends StatelessWidget {
  const _DoubanTabChip({
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
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoubanGridCard extends StatelessWidget {
  const _DoubanGridCard({required this.item, required this.onTap});

  final _DoubanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Material(
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Image.network(
                item.cover,
                fit: BoxFit.cover,
                width: double.infinity,
                headers: const {'Referer': 'https://movie.douban.com/'},
                errorBuilder: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.movie_rounded, size: 40),
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
        ),
        const SizedBox(height: 6),
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
    );
  }
}
