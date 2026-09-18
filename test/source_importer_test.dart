import 'dart:convert';

import 'package:skytv/core/models/parse_rule.dart';
import 'package:skytv/core/models/source_kind.dart';
import 'package:skytv/core/parser/source_importer.dart';
import 'package:skytv/core/source/source_id.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes api url and builds stable source id', () {
    final apiUrl = normalizeApiUrl('https://example.com/api.php/provide/vod/');

    expect(apiUrl, 'https://example.com/api.php/provide/vod/at/json');
    expect(buildSourceId('示例', apiUrl), buildSourceId('示例', apiUrl));
  });

  test('imports array sources and deduplicates by generated source id', () {
    final result = importSourcesFromJson('''
      [
        {"name":"示例","api_url":"https://example.com/api.php/provide/vod"},
        {"name":"示例","api_url":"https://example.com/api.php/provide/vod/at/json"}
      ]
    ''');

    expect(result.errors, isEmpty);
    expect(result.sources, hasLength(1));
    expect(result.sources.single.apiUrl, endsWith('/at/json'));
  });

  test('collects item errors without dropping valid sources', () {
    final result = importSourcesFromJson('''
      {
        "sources": [
          {"name":"可用","api_url":"https://example.com/api.php/provide/vod"},
          {"name":"","api_url":"https://bad.example.com"}
        ]
      }
    ''');

    expect(result.sources, hasLength(1));
    expect(result.errors, hasLength(1));
  });

  test('imports tvbox config sites, lives and unsupported reasons', () {
    final result = importSourcesFromJson(
      jsonEncode({
        'sites': [
          {
            'key': 'drpyS_测试',
            'name': '测试(DS)',
            'type': 4,
            'api': 'http://127.0.0.1:5757/api/测试?pwd=dzyyds',
            'ext': 'ext1',
          },
          {
            'key': '采集',
            'name': '采集站',
            'type': 1,
            'api': 'https://example.com/api.php/provide/vod/',
          },
          {
            'key': 'drpy2_豆瓣',
            'name': '豆瓣(DR2)',
            'type': 3,
            'api': 'http://127.0.0.1:5757/public/drpy/drpy2.min.js',
            'ext': 'http://127.0.0.1:5757/js/豆瓣.js',
          },
        ],
        'lives': [
          {'name': '直播', 'type': 0, 'url': 'https://example.com/tv.m3u'},
          {'name': '重复', 'type': 0, 'url': 'https://example.com/tv.m3u'},
          {'name': '无地址', 'type': 1},
        ],
        'parses': [
          {'name': 'J1', 'url': 'https://jx.example.com/?url=', 'type': 1},
          {
            'name': 'W1',
            'url': 'https://web.example.com/?url=',
            'type': 0,
            'header': {'User-Agent': 'okhttp/3.12.13'},
          },
          {'name': 'J1', 'url': 'https://jx.example.com/?url=', 'type': 1},
          {'name': '本地', 'url': 'csp_local', 'type': 1},
        ],
      }),
    );

    expect(result.errors, hasLength(1));
    expect(result.errors.single, contains('豆瓣(DR2)'));
    expect(result.sources, hasLength(2));
    final ds = result.sources.firstWhere(
      (source) => source.kind == SourceKind.ds,
    );
    expect(ds.apiUrl, 'http://127.0.0.1:5757/api/测试?pwd=dzyyds');
    expect(ds.extend, 'ext1');
    final cms = result.sources.firstWhere(
      (source) => source.kind == SourceKind.maccms,
    );
    expect(cms.apiUrl, endsWith('/at/json'));
    expect(result.iptvSubscriptions, hasLength(1));
    expect(result.iptvSubscriptions.single.url, 'https://example.com/tv.m3u');
    expect(result.parseRules, hasLength(2));
    expect(result.parseRules.first.type, ParseRuleType.json);
    expect(result.parseRules.last.type, ParseRuleType.web);
    expect(result.parseRules.last.header['User-Agent'], 'okhttp/3.12.13');
  });
}
