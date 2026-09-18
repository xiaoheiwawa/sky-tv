import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 局域网导入服务：手机扫码打开网页，把影视源配置推送到本机。
///
/// 只在弹窗存活期间监听，`onPayload` 返回给网页展示的结果文本。
class LanImportServer {
  LanImportServer._(this._server, this._onPayload);

  static const defaultPort = 9978;
  static const _portTries = 20;

  final HttpServer _server;
  final Future<String> Function(String payload) _onPayload;

  int get port => _server.port;

  static Future<LanImportServer?> start({
    required Future<String> Function(String payload) onPayload,
    int startPort = defaultPort,
  }) async {
    for (var offset = 0; offset < _portTries; offset++) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          startPort + offset,
        );
        final instance = LanImportServer._(server, onPayload);
        instance._serve();
        return instance;
      } on SocketException {
        continue;
      }
    }
    return null;
  }

  Future<void> stop() => _server.close(force: true);

  /// 二维码与网页展示用的候选地址（排除回环与链路本地地址）。
  static Future<List<String>> addresses(int port) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final result = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback || address.address.startsWith('169.254.')) {
          continue;
        }
        result.add('http://${address.address}:$port');
      }
    }
    return result;
  }

  void _serve() {
    _server.listen(
      (request) async {
        try {
          await _handle(request);
        } catch (_) {
          await _reply(
            request.response,
            HttpStatus.internalServerError,
            '导入服务异常',
          );
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && (path.isEmpty || path == '/')) {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_page);
      await request.response.close();
      return;
    }
    if (request.method == 'POST' && path == '/import') {
      final payload = (await utf8.decoder.bind(request).join()).trim();
      if (payload.isEmpty) {
        await _reply(
          request.response,
          HttpStatus.badRequest,
          '内容为空：粘贴影视源 JSON / TVBox 配置，或填写订阅地址',
        );
        return;
      }
      await _reply(request.response, HttpStatus.ok, await _onPayload(payload));
      return;
    }
    await _reply(request.response, HttpStatus.notFound, '未找到该路径');
  }

  Future<void> _reply(HttpResponse response, int status, String message) async {
    response.statusCode = status;
    response.headers.contentType = ContentType(
      'text',
      'plain',
      charset: 'utf-8',
    );
    response.write(message);
    await response.close();
  }

  static const _page = r'''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>sky-tv 导入影视源</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 20px; background: #101418; color: #e6e9ee;
         font: 15px/1.6 -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; }
  h1 { font-size: 18px; margin: 0 0 4px; }
  p.hint { color: #9aa4b2; font-size: 13px; margin: 0 0 16px; }
  textarea { width: 100%; box-sizing: border-box; min-height: 200px; padding: 12px;
             border-radius: 10px; border: 1px solid #2b333d; background: #171d23;
             color: #e6e9ee; font: 13px/1.5 ui-monospace, Menlo, Consolas, monospace;
             resize: vertical; }
  .row { display: flex; gap: 10px; align-items: center; margin: 12px 0; flex-wrap: wrap; }
  button { flex: 1 1 auto; min-width: 140px; padding: 12px 18px; border: 0; border-radius: 10px;
           background: #4c8dff; color: #fff; font-size: 15px; font-weight: 600; }
  label.file { color: #9aa4b2; font-size: 13px; }
  #result { margin-top: 14px; padding: 12px; border-radius: 10px; background: #171d23;
            border: 1px solid #2b333d; font-size: 13px; white-space: pre-wrap; }
</style>
</head>
<body>
<h1>导入影视源</h1>
<p class="hint">粘贴 sky-tv 影视源 JSON、TVBox 配置（sites/lives/parses），或直接填写订阅地址后提交。</p>
<textarea id="payload" placeholder="sites/parses JSON 或 http://example.com/config.json"></textarea>
<div class="row">
  <label class="file">选择文件：<input type="file" id="file" accept=".json,.txt,application/json"></label>
</div>
<div class="row"><button id="submit">提交到 sky-tv</button></div>
<div id="result">等待提交…</div>
<script>
  var payload = document.getElementById('payload');
  var result = document.getElementById('result');
  document.getElementById('file').addEventListener('change', function (event) {
    var file = event.target.files && event.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () { payload.value = reader.result; };
    reader.readAsText(file);
  });
  document.getElementById('submit').addEventListener('click', function () {
    var text = payload.value.trim();
    if (!text) { result.textContent = '请先粘贴内容或填写订阅地址'; return; }
    result.textContent = '正在导入…';
    fetch('/import', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain;charset=utf-8' },
      body: text
    }).then(function (response) {
      return response.text();
    }).then(function (text) {
      result.textContent = text;
    }).catch(function (error) {
      result.textContent = '请求失败：' + error;
    });
  });
</script>
</body>
</html>
''';
}
