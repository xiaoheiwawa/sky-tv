import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/app_providers.dart';

/// 推荐位编辑页：管理首页展示的榜单与快捷入口。
class HomeEditPage extends ConsumerWidget {
  const HomeEditPage({super.key});

  static const _doubanLists = [
    '华语口碑剧集榜',
    '一周口碑电影榜',
    '全球口碑榜',
    '华语口碑综艺榜',
    '华语口碑动漫榜',
    '纪录片榜',
    '短片榜',
  ];

  static const _quickAccess = [
    (Icons.favorite_rounded, '我的收藏'),
    (Icons.history_rounded, '历史记录'),
    (Icons.video_file_rounded, '本地视频'),
    (Icons.cloud_rounded, '网盘登录'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final hasRecommend = feed.maybeWhen(
      data: (homeFeed) => homeFeed.recommend.isNotEmpty,
      orElse: () => false,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('推荐位编辑'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle(title: '豆瓣榜单'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _doubanLists)
                FilterChip(
                  label: Text(name),
                  selected: name == '华语口碑剧集榜',
                  onSelected: (_) {},
                ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: '站点推荐'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('为你推荐'),
              subtitle: Text(hasRecommend ? '已启用' : '暂无推荐数据'),
              trailing: Switch(value: hasRecommend, onChanged: (_) {}),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: '快捷入口'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (icon, label) in _quickAccess)
                _QuickAccessEditCard(icon: icon, label: label),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _QuickAccessEditCard extends StatelessWidget {
  const _QuickAccessEditCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Icon(Icons.drag_handle_rounded, size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
