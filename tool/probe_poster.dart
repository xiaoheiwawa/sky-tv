// 联调探针：统计各源列表/详情的 poster 缺失率与地址形态（相对/协议相对）。
//
// 用法：dart run tool/probe_poster.dart [配置文件路径] [抽样站点数]
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:skytv/core/parser/source_importer.dart';
import 'package:skytv/core/upstream/video_api.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? 'D:/temp/hometv_config.json' : args[0];
  final limit = args.length > 1 ? int.parse(args[1]) : 60;
  final imported = importSourcesFromJson(File(path).readAsStringSync());
  final sources = imported.sources.take(limit).toList();
  final api = VideoApi();

  var listMissing = 0;
  var listRelative = 0;
  var detailMissing = 0;
  var detailKept = 0;
  var probed = 0;
  final detailLost = <String>[];
  final relative = <String>[];
  final listMissingNames = <String>[];

  Future<void> probe(source) async {
    try {
      final categories = await api.categories(source);
      if (categories.isEmpty) {
        return;
      }
      final items = await api.categoryVideos(source, categories.first.id, 1);
      final first = items.firstOrNull;
      if (first == null) {
        return;
      }
      probed++;
      final listPoster = first.poster;
      if (listPoster == null || listPoster.isEmpty) {
        listMissing++;
        listMissingNames.add(source.name);
      } else if (!Uri.parse(listPoster).hasScheme) {
        listRelative++;
        relative.add(listPoster);
      }
      final detail = await api.detail(source, first.id);
      final detailPoster = detail?.poster;
      if (detailPoster == null || detailPoster.isEmpty) {
        detailMissing++;
        if (listPoster != null && listPoster.isNotEmpty) {
          detailLost.add('${source.name} -> $listPoster');
        }
      } else {
        detailKept++;
        if (!Uri.parse(detailPoster).hasScheme) {
          relative.add(detailPoster);
        }
      }
    } catch (_) {}
  }

  for (var i = 0; i < sources.length; i += 8) {
    await Future.wait(sources.skip(i).take(8).map(probe));
  }
  print('PROBED=$probed');
  print('LIST missing=$listMissing relative=$listRelative');
  print('DETAIL kept=$detailKept missing=$detailMissing');
  print('LIST_MISSING_SAMPLE ${listMissingNames.take(6).toList()}');
  print('DETAIL_LOST_SAMPLE ${detailLost.take(6).toList()}');
  print('RELATIVE_SAMPLE ${relative.take(6).toList()}');
  api.close();
}
