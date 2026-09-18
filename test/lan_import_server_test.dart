import 'dart:convert';
import 'dart:io';

import 'package:skytv/core/lan/lan_import_server.dart';
import 'package:test/test.dart';

void main() {
  test('提供导入页面并把提交内容交给回调', () async {
    final received = <String>[];
    final server = await LanImportServer.start(
      startPort: 19978,
      onPayload: (payload) async {
        received.add(payload);
        return '导入完成：导入 2 个影视源，错误 0 个';
      },
    );
    expect(server, isNotNull);
    final client = HttpClient();
    try {
      final page = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server!.port}/'))
          .then((request) => request.close());
      expect(page.statusCode, HttpStatus.ok);
      expect(await page.transform(utf8.decoder).join(), contains('导入影视源'));

      final post = await client
          .postUrl(Uri.parse('http://127.0.0.1:${server.port}/import'))
          .then((request) {
            request.headers.contentType = ContentType(
              'text',
              'plain',
              charset: 'utf-8',
            );
            request.write('{sources:[]}');
            return request.close();
          });
      expect(post.statusCode, HttpStatus.ok);
      expect(await post.transform(utf8.decoder).join(), contains('导入完成'));
      expect(received, ['{sources:[]}']);

      final empty = await client
          .postUrl(Uri.parse('http://127.0.0.1:${server.port}/import'))
          .then((request) => request.close());
      expect(empty.statusCode, HttpStatus.badRequest);
      await empty.drain<void>();

      final missing = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/nope'))
          .then((request) => request.close());
      expect(missing.statusCode, HttpStatus.notFound);
      await missing.drain<void>();
    } finally {
      client.close(force: true);
      await server!.stop();
    }
  });
}
