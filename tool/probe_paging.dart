import 'dart:io';

import 'package:skytv/core/models/source_kind.dart';
import 'package:skytv/core/parser/source_importer.dart';
import 'package:skytv/core/upstream/video_api.dart';

// 联调探针：实测真实源的分页返回（pagecount 字段与逐页条数），定位 iPad 端翻页失效根因。
// 用法：dart run tool/probe_paging.dart [配置文件路径] [抽样站点数]
// ignore_for_file: avoid_print
Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'D:/temp/hometv_config.json' : args[0];
  final limit = args.length > 1 ? int.parse(args[1]) : 6;
  final imported = importSourcesFromJson(File(path).readAsStringSync());
  final sources = imported.sources
      .where((s) => s.kind == SourceKind.ds || s.kind == SourceKind.maccms)
      .toList();
  print(
    'IMPORT sources=${sources.length} '
    'ds=${sources.where((s) => s.kind == SourceKind.ds).length} '
    'maccms=${sources.where((s) => s.kind == SourceKind.maccms).length}',
  );
  final api = VideoApi();

  for (final source in sources.take(limit)) {
    try {
      final categories = await api.categories(source);
      if (categories.isEmpty) {
        print('=== ${source.name} 无分类');
        continue;
      }
      final target = categories.firstWhere(
        (c) =>
            c.name.contains('电视剧') ||
            c.name.contains('剧') ||
            c.name.contains('电视'),
        orElse: () => categories.first,
      );
      print('=== ${source.name} 分类=${target.name}');
      for (var page = 1; page <= 5; page++) {
        try {
          final r = await api.categoryPage(source, target.id, page);
          print(
            '  p$page 条数=${r.items.length} '
            'pageCount=${r.pageCount} hasMoreAfter=${r.hasMoreAfter(page)}',
          );
          if (r.items.isEmpty) {
            break;
          }
        } catch (error) {
          print('  p$page ERROR=$error');
          break;
        }
      }
    } catch (error) {
      print('=== ${source.name} 拉分类失败 $error');
    }
  }
}
