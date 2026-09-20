import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'player_surface.dart';

/// 电视遥控器播放层（点播、直播共用）。
///
/// 交互参考 FongMi / WebHomeTV 的遥控器习惯：
/// - 控制条默认隐藏；
/// - 控制条隐藏时 ←/→ 快退/快进，↑ 呼出控制条，确认键播放/暂停；
/// - ↓ 呼出控制条并把焦点放到操作按钮（选集、下一集等）；
/// - 焦点在控制条内时，方向键在按钮间移动，确认键执行按钮；
/// - 返回键先收起控制条，控制条已收起时交回路由退出播放页。
class TvPlayerControls extends StatefulWidget {
  const TvPlayerControls({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    this.selectorAction,
    this.onNext,
    this.onPrevious,
    this.onBack,
    this.loading = false,
  });

  final VideoController controller;
  final String title;
  final ValueListenable<String> subtitle;
  final PlayerSurfaceAction? selectorAction;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onBack;
  final bool loading;

  @override
  State<TvPlayerControls> createState() => _TvPlayerControlsState();
}

class _TvPlayerControlsState extends State<TvPlayerControls> {
  /// 每次快退/快进的步长。
  static const _seekStep = Duration(seconds: 10);

  /// 控制条自动收起时间。
  static const _hideDelay = Duration(seconds: 6);

  final _rootFocus = FocusNode(debugLabel: 'tv-player');
  final _playFocus = FocusNode(debugLabel: 'tv-player-play');
  final _actionFocus = FocusNode(debugLabel: 'tv-player-actions');
  Timer? _hideTimer;
  Timer? _hintTimer;
  bool _visible = false;
  Duration? _seekHint;

  Player get _player => widget.controller.player;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    _rootFocus.dispose();
    _playFocus.dispose();
    _actionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = _seekHint;
    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hint != null) Center(child: _SeekHint(target: hint)),
          _AnimatedBar(
            visible: _visible,
            alignment: Alignment.topLeft,
            child: _TitleBar(
              title: widget.title,
              subtitle: widget.subtitle,
              onBack: _hideControls,
            ),
          ),
          _AnimatedBar(
            visible: _visible,
            alignment: Alignment.bottomCenter,
            child: _ControlBar(
              controller: widget.controller,
              playFocus: _playFocus,
              actionFocus: _actionFocus,
              selectorAction: widget.selectorAction,
              onNext: widget.onNext,
              onPrevious: widget.onPrevious,
              onInteract: _armHideTimer,
              onFullscreen: () => _toggleFullscreen(context),
            ),
          ),
          if (widget.loading)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 2,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      if (_visible) {
        _hideControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (FocusManager.instance.primaryFocus != _rootFocus) {
      // 焦点在控制条内：方向键移动焦点、确认键交给按钮。
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _seek(key == LogicalKeyboardKey.arrowLeft ? -_seekStep : _seekStep);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) {
        _showControls(toActions: key == LogicalKeyboardKey.arrowDown);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) {
        _showControls(toActions: true);
      }
      return KeyEventResult.handled;
    }
    if (_isConfirmKey(key)) {
      if (event is KeyUpEvent) {
        if (_visible) {
          _hideControls();
        } else {
          unawaited(_player.playOrPause());
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isConfirmKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  void _seek(Duration delta) {
    final duration = _player.state.duration;
    if (duration <= Duration.zero) {
      return;
    }
    final target = _player.state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    setState(() {
      _visible = false;
      _seekHint = clamped;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _seekHint = null);
      }
    });
    unawaited(_player.seek(clamped));
  }

  void _showControls({required bool toActions}) {
    setState(() => _visible = true);
    _armHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = toActions ? _actionFocus : _playFocus;
      if (target.context != null) {
        target.requestFocus();
      }
    });
  }

  void _hideControls() {
    _hideTimer?.cancel();
    if (!_visible) {
      return;
    }
    setState(() => _visible = false);
    _rootFocus.requestFocus();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && !_player.state.playing) {
        // 暂停时保留控制条，方便继续选集或退出。
        _armHideTimer();
        return;
      }
      if (mounted) {
        _hideControls();
      }
    });
  }

  Future<void> _toggleFullscreen(BuildContext context) async {
    _armHideTimer();
    if (isFullscreen(context)) {
      await exitFullscreen(context);
    } else {
      await enterFullscreen(context);
    }
    if (mounted) {
      setState(() {});
    }
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: ExcludeFocus(
          excluding: !visible,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final ValueListenable<String> subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            tooltip: '收起',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                ValueListenableBuilder<String>(
                  valueListenable: subtitle,
                  builder: (context, value, _) => Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.controller,
    required this.playFocus,
    required this.actionFocus,
    required this.selectorAction,
    required this.onNext,
    required this.onPrevious,
    required this.onInteract,
    required this.onFullscreen,
  });

  final VideoController controller;
  final FocusNode playFocus;
  final FocusNode actionFocus;
  final PlayerSurfaceAction? selectorAction;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onInteract;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<Duration>(
            stream: player.stream.position,
            initialData: player.state.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.state.duration;
              final value = duration.inMilliseconds <= 0
                  ? 0.0
                  : (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    );
              return Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<bool>(
            stream: player.stream.playing,
            initialData: player.state.playing,
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return Row(
                children: [
                  _BarButton(
                    focusNode: playFocus,
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    label: playing ? '暂停' : '播放',
                    onPressed: () {
                      onInteract();
                      unawaited(player.playOrPause());
                    },
                  ),
                  if (onPrevious != null)
                    _BarButton(
                      icon: Icons.skip_previous_rounded,
                      label: '上一个',
                      onPressed: () {
                        onInteract();
                        onPrevious!();
                      },
                    ),
                  if (onNext != null)
                    _BarButton(
                      icon: Icons.skip_next_rounded,
                      label: '下一个',
                      onPressed: () {
                        onInteract();
                        onNext!();
                      },
                    ),
                  if (selectorAction != null)
                    _BarButton(
                      focusNode: actionFocus,
                      icon: selectorAction!.icon,
                      label: selectorAction!.tooltip,
                      onPressed: () {
                        onInteract();
                        selectorAction!.onPressed(context);
                      },
                    ),
                  _BarButton(
                    icon: Icons.fullscreen_rounded,
                    label: '全屏',
                    onPressed: onFullscreen,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: _focused
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          focusNode: widget.focusNode,
          onFocusChange: (value) => setState(() => _focused = value),
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

class _SeekHint extends StatelessWidget {
  const _SeekHint({required this.target});

  final Duration target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatDuration(target),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$secondText';
  }
  return '$minutes:$secondText';
}
