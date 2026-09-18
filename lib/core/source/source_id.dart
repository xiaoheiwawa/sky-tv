import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/source_kind.dart';

String normalizeSourceName(String value) => value.trim();

String normalizeApiUrl(String value, {SourceKind kind = SourceKind.maccms}) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    throw FormatException('api_url 只支持 http/https: $value');
  }
  if (kind == SourceKind.ds) {
    // DS 接口地址带 pwd/extend 等查询参数，按原样保留。
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    throw FormatException('api_url 不是有效 URL: $value');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw FormatException('api_url 只支持 http/https: $value');
  }
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (path.endsWith('/at/json')) {
    return uri.replace(path: path).toString();
  }
  return uri.replace(path: '$path/at/json').toString();
}

String buildSourceId(String normalizedName, String normalizedApiUrl) {
  final bytes = utf8.encode('$normalizedName|$normalizedApiUrl');
  return sha1.convert(bytes).toString().substring(0, 16);
}

String buildHash(String value) => sha256.convert(utf8.encode(value)).toString();
