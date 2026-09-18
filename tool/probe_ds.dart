// 联调探针：导入 TVBox 配置后，对真实 DS 源跑一遍 首页/分类/详情/播放。
//
// 用法：dart run tool/probe_ds.dart [配置文件路径] [抽样站点数]
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:skytv/core/models/source_kind.dart';
import 'package:skytv/core/parser/source_importer.dart';
import 'package:skytv/core/upstream/parse_resolver.dart';
import 'package:skytv/core/upstream/video_api.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'D:/temp/hometv_config.json' : args[0];
  final limit = args.length > 1 ? int.parse(args[1]) : 6;
  final raw = File(path).readAsStringSync();
  final imported = importSourcesFromJson(raw);
  final ds = imported.sources.where((s) => s.kind == SourceKind.ds).toList();
  final maccms = imported.sources
      .where((s) => s.kind == SourceKind.maccms)
      .length;
  print(
    'IMPORT sources=${imported.sources.length} ds=${ds.length} '
    'maccms=$maccms errors=${imported.errors.length} '
    'lives=${imported.iptvSubscriptions.length} '
    'parses=${imported.parseRules.length}',
  );
  print('ERR_SAMPLE ${imported.errors.take(3).toList()}');
  print('LIVES ${imported.iptvSubscriptions.map((s) => s.url).toList()}');
  print('PARSES ${imported.parseRules.map((r) => r.name).toList()}');

  final api = VideoApi();
  final resolver = ParseResolver();
  final rules = imported.parseRules;
  var direct = 0;
  var parsed = 0;
  var failed = 0;
  var empty = 0;

  Future<void> probe(String name) async {
    final source = ds.firstWhere((s) => s.name == name);
    try {
      final categories = await api.categories(source);
      if (categories.isEmpty) {
        empty++;
        print('EMPTY  $name 无分类');
        return;
      }
      final items = await api.categoryVideos(source, categories.first.id, 1);
      if (items.isEmpty) {
        empty++;
        print('EMPTY  $name 分类无片');
        return;
      }
      final detail = await api.detail(source, items.first.id);
      final line = detail?.playLines.firstOrNull;
      final episode = line?.episodes.firstOrNull;
      if (line == null || episode == null) {
        empty++;
        print('EMPTY  $name 无分集');
        return;
      }
      final resolution = await api.resolvePlay(
        source,
        line: line,
        episode: episode,
      );
      if (!resolution.needsParse) {
        direct++;
        print('DIRECT $name ${resolution.url}');
        return;
      }
      final result = await resolver.resolve(resolution.url, rules);
      parsed++;
      print('PARSED $name [${result.ruleName}] ${result.url}');
    } catch (error) {
      failed++;
      final text = error.toString();
      print(
        'FAIL   $name ${text.length > 160 ? text.substring(0, 160) : text}',
      );
    }
  }

  final names = ds.map((s) => s.name).take(limit).toList();
  await Future.wait(names.map(probe));
  api.close();
  resolver.close();
  print('SUMMARY direct=$direct parsed=$parsed empty=$empty failed=$failed');
}
