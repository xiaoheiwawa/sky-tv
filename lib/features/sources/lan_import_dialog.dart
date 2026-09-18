import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/lan/lan_import_server.dart';
import '../../data/repositories/app_providers.dart';

/// 局域网导入：手机扫码打开网页，把影视源配置推送到本机。
Future<void> showLanImportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _LanImportDialog(),
  );
}

class _LanImportDialog extends ConsumerStatefulWidget {
  const _LanImportDialog();

  @override
  ConsumerState<_LanImportDialog> createState() => _LanImportDialogState();
}

class _LanImportDialogState extends ConsumerState<_LanImportDialog> {
  LanImportServer? _server;
  List<String> _addresses = const [];
  String _status = '正在启动局域网服务...';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    final server = _server;
    _server = null;
    unawaited(server?.stop());
    super.dispose();
  }

  Future<void> _start() async {
    final server = await LanImportServer.start(onPayload: _importPayload);
    if (!mounted) {
      await server?.stop();
      return;
    }
    if (server == null) {
      setState(() {
        _status = '端口 ${LanImportServer.defaultPort} 起连续 20 个端口都被占用，无法启动局域网导入。';
      });
      return;
    }
    final addresses = await LanImportServer.addresses(server.port);
    if (!mounted) {
      await server.stop();
      return;
    }
    setState(() {
      _server = server;
      _addresses = addresses;
      _ready = addresses.isNotEmpty;
      _status = addresses.isEmpty
          ? '没有找到局域网地址，请先让设备连上 Wi-Fi 或有线网络。'
          : '等待手机提交...';
    });
  }

  Future<String> _importPayload(String payload) async {
    try {
      final repo = await ref.read(sourceRepositoryProvider.future);
      final value = payload.trim();
      final result = value.startsWith('http://') || value.startsWith('https://')
          ? await repo.importSubscriptionUrl('远程订阅', value)
          : repo.importJson(value);
      ref.invalidate(sourcesProvider);
      ref.invalidate(parseRulesProvider);
      if (mounted) {
        setState(() => _status = result.summary);
      }
      return '导入完成：${result.summary}';
    } catch (error) {
      final message = '导入失败：$error';
      if (mounted) {
        setState(() => _status = message);
      }
      return message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = _addresses.isEmpty ? null : _addresses.first;
    return AlertDialog(
      title: const Text('局域网导入'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '手机连同一个 Wi-Fi 后扫码，在打开的网页里粘贴影视源 JSON、'
                'TVBox 配置或订阅地址。',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              if (url != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(data: url, size: 180),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  url,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final extra in _addresses.skip(1))
                  SelectableText(
                    extra,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Text(
                _status,
                style: TextStyle(
                  color: _ready ? scheme.onSurfaceVariant : scheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
