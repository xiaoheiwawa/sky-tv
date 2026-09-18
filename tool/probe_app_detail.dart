import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:skytv/core/models/source_kind.dart';
import 'package:skytv/core/models/video_source.dart';
import 'package:skytv/core/upstream/video_api.dart';

Future<void> main(List<String> args) async {
  final name = args.isNotEmpty ? args[0] : '木偶[盘]';
  final apiUrl = args.length > 1
      ? args[1]
      : 'https://mytv.free178.xx.kg/api/木偶[盘]?pwd=dzyyds';
  final source = VideoSource.create(
    name: name,
    apiUrl: apiUrl,
    kind: SourceKind.ds,
  );
  final api = VideoApi();
  final raw = http.Client();
  try {
    final items = await api.latestVideos(source);
    print('列表条数     = ${items.length}');
    for (final item in items.take(2)) {
      print('\n=== 条目: ${item.title}  id=${item.id}');
      final MediaDetailHolder holder = MediaDetailHolder();
      try {
        final detail = await api.detail(source, item.id);
        if (detail == null) {
          print('  ✗ 详情 null');
          continue;
        }
        holder.detail = detail;
        print('  ✓ 详情 title=${detail.title} 线路=${detail.playLines.length} 封面=${detail.poster}');
        for (final line in detail.playLines) {
          print('    线路 ${line.name} 集数=${line.episodes.length}');
        }
        for (final line in detail.playLines) {
          if (line.episodes.isEmpty) continue;
          final episode = line.episodes.first;
          final uri = buildSourceUri(source, {
            'play': episode.url,
            if (line.flag.isNotEmpty) 'flag': line.flag,
          });
          try {
            final resolution = await api.resolvePlay(
              source,
              line: line,
              episode: episode,
            );
            print('  ✓ 播放[${line.name}] 直链=${resolution.url.substring(0, resolution.url.length.clamp(0, 110))}');
            print('     headers=${resolution.headers}');
          } catch (error) {
            print('  ✗ 播放[${line.name}] 失败：$error');
            final response = await raw.get(uri).timeout(const Duration(seconds: 30));
            final body = utf8.decode(response.bodyBytes, allowMalformed: true);
            print('     原始 HTTP ${response.statusCode} len=${body.length} 前 200: ${body.substring(0, body.length.clamp(0, 200))}');
          }
        }
      } catch (error) {
        print('  ✗ 异常：$error');
      }
    }
  } catch (error) {
    print('列表异常：$error');
  } finally {
    api.close();
    raw.close();
  }
}

class MediaDetailHolder {
  Object? detail;
}