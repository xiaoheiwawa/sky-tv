import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/iptv_models.dart';

class LiveChannelTile extends StatefulWidget {
  const LiveChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.selected = false,
    this.dark = false,
    this.autofocus = false,
  });

  final IptvChannel channel;
  final VoidCallback onTap;
  final bool selected;
  final bool dark;
  final bool autofocus;

  @override
  State<LiveChannelTile> createState() => _LiveChannelTileState();
}

class _LiveChannelTileState extends State<LiveChannelTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = widget.dark;
    final selected = widget.selected;
    final foreground = dark ? Colors.white : scheme.onSurface;
    final secondary = dark ? Colors.white70 : scheme.onSurfaceVariant;
    final selectedFill = dark
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.primaryContainer.withValues(alpha: 0.55);

    const radius = BorderRadius.all(Radius.circular(8));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Material(
        color: selected ? selectedFill : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (value) => setState(() => _focused = value),
          onTap: widget.onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _ChannelLogo(url: widget.channel.logo, dark: dark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.channel.group ?? '未分组',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: secondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.play_arrow_rounded,
                    size: 20,
                    color: dark ? Colors.white70 : scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url, required this.dark});

  final String? url;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: dark ? Colors.white10 : scheme.surfaceContainerHighest,
      child: Icon(
        Icons.live_tv_rounded,
        size: 18,
        color: dark ? Colors.white54 : scheme.onSurfaceVariant,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url == null || url!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.contain,
                memCacheWidth: 72,
                memCacheHeight: 72,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
