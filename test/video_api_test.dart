import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skytv/core/models/media_models.dart';
import 'package:skytv/core/models/source_kind.dart';
import 'package:skytv/core/models/video_source.dart';
import 'package:skytv/core/upstream/video_api.dart';
import 'package:test/test.dart';

VideoSource _dsSource() => VideoSource.create(
  name: 'DS',
  apiUrl: 'http://127.0.0.1:5757/api/测试[书]?pwd=dzyyds',
  kind: SourceKind.ds,
);

VideoSource _maccmsSource() => VideoSource.create(
  name: 'CMS',
  apiUrl: 'https://example.com/api.php/provide/vod/',
);

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  test('keeps ds query params and appends extend and action params', () {
    final source = VideoSource.create(
      name: 'DS',
      apiUrl: 'http://127.0.0.1:5757/api/测试[书]?pwd=dzyyds',
      kind: SourceKind.ds,
      extend: 'ext1',
    );

    final uri = buildSourceUri(source, const {
      'ac': 'list',
      't': '1',
      'pg': '2',
    });

    expect(uri.host, '127.0.0.1');
    expect(uri.port, 5757);
    expect(uri.queryParameters['pwd'], 'dzyyds');
    expect(uri.queryParameters['extend'], 'ext1');
    expect(uri.queryParameters['t'], '1');
    expect(uri.queryParameters['pg'], '2');
  });

  test('normalizes maccms url without dropping its query', () {
    final source = VideoSource.create(
      name: 'CMS',
      apiUrl: 'https://example.com/api.php/provide/vod/?token=abc',
    );

    expect(
      source.apiUrl,
      'https://example.com/api.php/provide/vod/at/json?token=abc',
    );
    final uri = buildSourceUri(source, const {'ac': 'list'});
    expect(uri.queryParameters['ac'], 'list');
    expect(uri.queryParameters['token'], 'abc');
  });

  test(
    'uses ds query conventions for home, category, search and detail',
    () async {
      final seen = <Uri>[];
      final client = MockClient((request) async {
        seen.add(request.url);
        final query = request.url.queryParameters;
        if (query.containsKey('ids')) {
          return _json({
            'list': [
              {
                'vod_id': '1',
                'vod_name': '测试影片',
                'vod_play_from': '线路A',
                'vod_play_url': '第1集\$http://cdn.example.com/1.m3u8',
              },
            ],
          });
        }
        if (query.containsKey('wd')) {
          return _json({
            'list': [
              {'vod_id': '2', 'vod_name': '搜索结果'},
            ],
          });
        }
        if (query.containsKey('t')) {
          return _json({
            'list': [
              {'vod_id': '3', 'vod_name': '分类结果'},
            ],
          });
        }
        return _json({
          'class': [
            {'type_id': '1', 'type_name': '电影'},
          ],
          'list': [
            {'vod_id': '4', 'vod_name': '首页推荐'},
          ],
        });
      });
      final api = VideoApi(client: client);
      final source = _dsSource();

      expect((await api.categories(source)).single.name, '电影');
      expect((await api.latestVideos(source)).single.title, '首页推荐');
      expect((await api.categoryVideos(source, '1', 2)).single.title, '分类结果');
      expect((await api.search(source, '测试', 1)).single.title, '搜索结果');

      // 0/1 是首页请求，2 是分类，3 是搜索。
      expect(seen[2].queryParameters['t'], '1');
      expect(seen[2].queryParameters['pg'], '2');
      expect(seen[3].queryParameters['wd'], '测试');
      expect(
        seen.every((uri) => uri.queryParameters['pwd'] == 'dzyyds'),
        isTrue,
      );
    },
  );

  test('parses detail and resolves ds play url with server headers', () async {
    final client = MockClient((request) async {
      if (request.url.queryParameters.containsKey('play')) {
        expect(request.url.queryParameters['play'], 'pid-1');
        expect(request.url.queryParameters['flag'], '线路A');
        return _json({
          'url': 'http://cdn.example.com/1.m3u8',
          'type': 'hls',
          'headers': {'Referer': 'http://site.example.com/'},
        });
      }
      return _json({
        'list': [
          {
            'vod_id': '1',
            'vod_name': '测试影片',
            'vod_play_from': '线路A',
            'vod_play_url': '第1集\$pid-1',
          },
        ],
      });
    });
    final api = VideoApi(client: client);
    final source = _dsSource();

    final detail = await api.detail(source, '1');
    final line = detail!.playLines.single;
    expect(line.flag, '线路A');
    expect(line.episodes.single.url, 'pid-1');

    final resolution = await api.resolvePlay(
      source,
      line: line,
      episode: line.episodes.single,
    );
    expect(resolution.url, 'http://cdn.example.com/1.m3u8');
    expect(resolution.headers['Referer'], 'http://site.example.com/');
  });

  test('flags ds episodes that need an external parser', () async {
    final client = MockClient(
      (request) async => _json({
        'url': 'http://site.example.com/play/1-1.html',
        'parse': 1,
        'jx': 1,
        'header': {'Referer': 'http://site.example.com/'},
      }),
    );
    final api = VideoApi(client: client);

    final resolution = await api.resolvePlay(
      _dsSource(),
      line: const PlayLine(name: '线路A', flag: '线路A', episodes: []),
      episode: const Episode(title: '第1集', url: 'pid-1'),
    );
    expect(resolution.url, 'http://site.example.com/play/1-1.html');
    expect(resolution.needsParse, isTrue);
    expect(resolution.headers['Referer'], 'http://site.example.com/');
  });

  test('surfaces upstream error payloads', () async {
    final client = MockClient(
      (request) async => _json({'error': 'Module 测试 not found'}),
    );
    final api = VideoApi(client: client);

    await expectLater(
      api.latestVideos(_dsSource()),
      throwsA(
        predicate(
          (Object error) => error.toString().contains('Module 测试 not found'),
        ),
      ),
    );
  });

  test('skips drpy no-data placeholders', () async {
    final client = MockClient(
      (request) async => _json({
        'list': [
          {
            'vod_id': 'no_data',
            'vod_name': '无数据,防无限请求',
            'vod_remarks': '不要点,会崩的',
          },
        ],
      }),
    );
    final api = VideoApi(client: client);

    await expectLater(
      api.latestVideos(_dsSource()),
      throwsA(predicate((Object error) => error.toString().contains('无数据'))),
    );
  });

  test('parses array shaped detail responses', () async {
    final client = MockClient(
      (request) async => _json([
        {'vod_id': '9', 'vod_name': '数组详情'},
      ]),
    );
    final api = VideoApi(client: client);

    final detail = await api.detail(_dsSource(), '9');
    expect(detail?.title, '数组详情');
  });

  test('maccms episodes play directly without an extra request', () async {
    final client = MockClient((request) async {
      fail('MacCMS 分集不应额外请求上游');
    });
    final api = VideoApi(client: client);

    final resolution = await api.resolvePlay(
      _maccmsSource(),
      line: const PlayLine(name: '线路', episodes: []),
      episode: const Episode(
        title: '第1集',
        url: 'http://cdn.example.com/1.m3u8',
      ),
    );
    expect(resolution.url, 'http://cdn.example.com/1.m3u8');
    expect(resolution.headers, isEmpty);
  });
}
