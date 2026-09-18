import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/iptv_models.dart';
import '../../core/models/media_models.dart';
import '../../core/models/parse_rule.dart';
import '../../core/models/source_kind.dart';
import '../../core/models/video_source.dart';
import '../../core/parser/source_importer.dart';
import '../../core/source/source_id.dart';
import '../../core/upstream/video_api.dart';
import '../storage/app_database.dart';

class SourceRepository {
  SourceRepository(
    this._db, {
    http.Client? client,
    Map<String, String> headers = const {},
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _headers = Map.unmodifiable(headers);

  final AppDatabase _db;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _headers;

  List<VideoSource> sources() => _db.loadSources();

  VideoSource? findById(String sourceId) {
    for (final source in sources()) {
      if (source.sourceId == sourceId) {
        return source;
      }
    }
    return null;
  }

  SourceImportResult importJson(String input) {
    final result = importSourcesFromJson(input);
    if (result.sources.isNotEmpty) {
      _db.upsertSources(result.sources);
    }
    _importIptvSubscriptions(result.iptvSubscriptions);
    if (result.parseRules.isNotEmpty) {
      _db.replaceParseRules(result.parseRules);
    }
    return result;
  }

  List<ParseRule> parseRules() => _db.loadParseRules();

  void clearParseRules() => _db.deleteParseRules();

  /// TVBox 配置里的直播订阅先落库，频道留给 LivePage 的到期刷新拉取。
  void _importIptvSubscriptions(List<ImportedIptvSubscription> subscriptions) {
    final now = DateTime.now();
    for (final item in subscriptions) {
      final id = buildHash(item.url).substring(0, 16);
      if (_db.loadIptvSubscription(id) != null) {
        continue;
      }
      _db.upsertIptvSubscription(
        IptvSubscription(
          id: id,
          name: item.name,
          url: item.url,
          enabled: true,
          lastUpdatedAt: now,
        ),
        const [],
      );
    }
  }

  Future<SourceImportResult> importSubscriptionUrl(
    String name,
    String url,
  ) async {
    final normalizedUrl = url.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('订阅地址只支持 http/https');
    }

    final id = buildHash(normalizedUrl).substring(0, 16);
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('订阅拉取失败：HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes);
    final hash = buildHash(body);
    final old = _db.loadSubscription(id);
    final now = DateTime.now();

    if (old != null && old.contentHash == hash) {
      _db.upsertSubscription(
        SourceSubscription(
          id: id,
          name: old.name,
          url: normalizedUrl,
          contentHash: hash,
          enabled: old.enabled,
          lastCheckedAt: now,
          lastUpdatedAt: old.lastUpdatedAt,
        ),
      );
      return const SourceImportResult(sources: [], errors: []);
    }

    final result = importJson(body);
    if (result.sources.isNotEmpty) {
      _db.upsertSources(result.sources);
    }
    _db.upsertSubscription(
      SourceSubscription(
        id: id,
        name: name.trim().isEmpty ? uri.host : name.trim(),
        url: normalizedUrl,
        contentHash: hash,
        enabled: true,
        lastCheckedAt: now,
        lastUpdatedAt: now,
      ),
    );
    return result;
  }

  /// 刷新到期订阅；返回成功处理的条数（单项失败不中断后续）。
  Future<int> refreshDueSubscriptions() async {
    final subscriptions = _db.loadDueSubscriptions();
    var ok = 0;
    for (final subscription in subscriptions) {
      try {
        await importSubscriptionUrl(subscription.name, subscription.url);
        ok++;
      } catch (_) {
        continue;
      }
    }
    return ok;
  }

  Future<LatencyTestResult> testLatencies(List<VideoSource> sources) async {
    final active = sources.where((source) => !source.disabled).toList();
    if (active.isEmpty) {
      return const LatencyTestResult(total: 0, succeeded: 0);
    }
    final queue = List<VideoSource>.from(active);
    const maxConcurrent = 16;
    var running = 0;
    var completed = 0;
    var succeeded = 0;
    final done = Completer<void>();

    void pump() {
      while (running < maxConcurrent && queue.isNotEmpty) {
        final source = queue.removeAt(0);
        running++;
        unawaited(
          _testLatency(source)
              .then((latency) {
                _db.updateSourceLatency(source.sourceId, latency);
                if (latency != null) {
                  succeeded++;
                }
              })
              .whenComplete(() {
                running--;
                completed++;
                if (completed == active.length) {
                  done.complete();
                } else {
                  pump();
                }
              }),
        );
      }
    }

    pump();
    await done.future;
    return LatencyTestResult(total: active.length, succeeded: succeeded);
  }

  void setDisabled(String sourceId, bool disabled) {
    _db.updateSourceDisabled(sourceId, disabled);
  }

  void delete(String sourceId) {
    _db.deleteSource(sourceId);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<int?> _testLatency(VideoSource source) async {
    final uri = buildSourceUri(source, _latencyQuery(source));
    final watch = Stopwatch()..start();
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(
            source.kind == SourceKind.ds
                ? const Duration(seconds: 15)
                : const Duration(seconds: 3),
          );
      if (response.statusCode != 200) {
        return null;
      }
      return watch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _latencyQuery(VideoSource source) =>
      switch (source.kind) {
        SourceKind.maccms => const {'ac': 'list'},
        SourceKind.ds => const {'filter': '1'},
      };
}

class LatencyTestResult {
  const LatencyTestResult({required this.total, required this.succeeded});

  final int total;
  final int succeeded;
}
