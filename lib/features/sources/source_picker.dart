import 'package:flutter/material.dart';

import '../../core/models/video_source.dart';
import '../../ui/widgets/state_views.dart';

/// 换源选择器：搜索 + 列数切换，点击条目即切换当前源。
Future<void> showSourcePicker(
  BuildContext context, {
  required List<VideoSource> sources,
  required String? selectedId,
  required ValueChanged<String> onSelected,
  VoidCallback? onManage,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _SourcePickerDialog(
      sources: sources,
      selectedId: selectedId,
      onSelected: (sourceId) {
        Navigator.of(dialogContext).pop();
        onSelected(sourceId);
      },
      onManage: onManage == null
          ? null
          : () {
              Navigator.of(dialogContext).pop();
              onManage();
            },
    ),
  );
}

class _SourcePickerDialog extends StatefulWidget {
  const _SourcePickerDialog({
    required this.sources,
    required this.selectedId,
    required this.onSelected,
    this.onManage,
  });

  final List<VideoSource> sources;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onManage;

  @override
  State<_SourcePickerDialog> createState() => _SourcePickerDialogState();
}

class _SourcePickerDialogState extends State<_SourcePickerDialog> {
  static const _columnOptions = [1, 2, 3, 4];

  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  int _columns = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<VideoSource> get _visible {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return widget.sources;
    }
    return widget.sources
        .where(
          (source) =>
              source.name.toLowerCase().contains(keyword) ||
              source.apiUrl.toLowerCase().contains(keyword),
        )
        .toList();
  }

  void _cycleColumns() {
    final index = _columnOptions.indexOf(_columns);
    setState(() {
      _columns = _columnOptions[(index + 1) % _columnOptions.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          minHeight: 320,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (value) => setState(() => _keyword = value),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '搜索源名称或接口',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _cycleColumns,
                    icon: Icon(
                      _columns == 1
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                    ),
                    tooltip: '切换列数（当前 $_columns 列）',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: '没有匹配的源',
                      message: '换个关键字试试。',
                      compact: true,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columns,
                        mainAxisExtent: 46,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final source = visible[index];
                        return _SourceOption(
                          source: source,
                          selected: source.sourceId == widget.selectedId,
                          onTap: () => widget.onSelected(source.sourceId),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      visible.length == widget.sources.length
                          ? '共 ${widget.sources.length} 个源'
                          : '共 ${widget.sources.length} 个源，匹配 ${visible.length} 个',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.onManage != null)
                    TextButton.icon(
                      onPressed: widget.onManage,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('源管理'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final VideoSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
