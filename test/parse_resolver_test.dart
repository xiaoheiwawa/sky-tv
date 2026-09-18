import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skytv/core/models/parse_rule.dart';
import 'package:skytv/core/upstream/parse_resolver.dart';
import 'package:test/test.dart';

ParseRule _jsonRule([String url = 'http://jx.example.com/api?url=']) =>
    ParseRule(id: 'r1', name: 'J1', url: url, type: ParseRuleType.json);

ParseRule _webRule([String url = 'http://web.example.com/?url=']) =>
    ParseRule(id: 'r2', name: 'W1', url: url, type: ParseRuleType.web);

void main() {
  test('resolves json parse services and appends the play url', () async {
    late Uri seen;
    final client = MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode({
          'code': 200,
          'url': 'https://cdn.example.com/a/index.m3u8',
        }),
        200,
      );
    });
    final resolver = ParseResolver(client: client);

    final result = await resolver.resolve(
      'https://site.example.com/play/1-1.html',
      [_jsonRule()],
    );

    expect(result.url, 'https://cdn.example.com/a/index.m3u8');
    expect(result.ruleName, 'J1');
    expect(seen.path, '/api');
    expect(
      seen.queryParameters['url'],
      'https://site.example.com/play/1-1.html',
    );
  });

  test('sniffs m3u8 out of web parse html', () async {
    final client = MockClient(
      (request) async => http.Response(
        'var player = {url: \u0022https:\\/\\/cdn.example.com\\/b\\/index.m3u8\u0022};',
        200,
      ),
    );
    final resolver = ParseResolver(client: client);

    final result = await resolver.resolve(
      'https://site.example.com/play/1-2.html',
      [_webRule()],
    );

    expect(result.url, 'https://cdn.example.com/b/index.m3u8');
  });

  test('resolves relative parse results against the parse service', () async {
    final client = MockClient(
      (request) async =>
          http.Response(jsonEncode({'url': '/hls/index.m3u8'}), 200),
    );
    final resolver = ParseResolver(client: client);

    final result = await resolver.resolve(
      'https://site.example.com/play/1-3.html',
      [_jsonRule('http://jx.example.com/hls/?url=')],
    );

    expect(result.url, 'http://jx.example.com/hls/index.m3u8');
  });

  test('falls back to the next parse service', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'jx.example.com') {
        return http.Response(jsonEncode({'msg': 'fail'}), 200);
      }
      return http.Response(
        jsonEncode({'url': 'https://cdn.example.com/c/index.m3u8'}),
        200,
      );
    });
    final resolver = ParseResolver(client: client);

    final result = await resolver.resolve(
      'https://site.example.com/play/1-4.html',
      [_jsonRule(), _webRule('http://web.example.com/player?url=')],
    );

    expect(result.url, 'https://cdn.example.com/c/index.m3u8');
    expect(result.ruleName, 'W1');
  });

  test('requires a configured parse service', () async {
    final resolver = ParseResolver(
      client: MockClient((request) async => http.Response('', 200)),
    );

    await expectLater(
      resolver.resolve('https://site.example.com/play/1-5.html', const []),
      throwsA(isA<FormatException>()),
    );
  });

  test('reports reasons when every parse service fails', () async {
    final resolver = ParseResolver(
      client: MockClient((request) async => http.Response('nope', 200)),
    );

    await expectLater(
      resolver.resolve('https://site.example.com/play/1-6.html', [_jsonRule()]),
      throwsA(predicate((Object error) => error.toString().contains('未解析出地址'))),
    );
  });
}
