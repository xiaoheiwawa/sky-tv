/// 解析（jx）规则类型。
///
/// TVBox 配置里 `type` 为 0 的走网页嗅探，1/2/3 都返回 JSON。
enum ParseRuleType { web, json }

/// 第三方播放解析服务（TVBox 配置里的 `parses`）。
class ParseRule {
  const ParseRule({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.header = const {},
  });

  factory ParseRule.fromJson(Map<String, Object?> json) {
    final name = _text(json['name'] ?? json['key']);
    final url = _text(json['url']);
    if (name.isEmpty || url.isEmpty) {
      throw const FormatException('解析服务缺少 name/url');
    }
    return ParseRule(
      id: buildParseRuleId(name, url),
      name: name,
      url: url,
      type: _type(json['type']),
      header: _headers(json['header'] ?? json['headers']),
    );
  }

  final String id;
  final String name;

  /// 解析服务地址，调用时把待解析地址拼在末尾。
  final String url;
  final ParseRuleType type;
  final Map<String, String> header;

  String get typeLabel => type == ParseRuleType.web ? '网页嗅探' : 'JSON';

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'type': type == ParseRuleType.web ? 0 : 1,
    'header': header,
  };
}

String buildParseRuleId(String name, String url) {
  final value = '$name|$url';
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return 'parse_${hash.toRadixString(16).padLeft(8, '0')}';
}

ParseRuleType _type(Object? value) {
  final parsed = value is int ? value : int.tryParse(_text(value));
  return parsed == 0 ? ParseRuleType.web : ParseRuleType.json;
}

Map<String, String> _headers(Object? value) {
  if (value is! Map) {
    return const {};
  }
  final result = <String, String>{};
  value.forEach((key, item) {
    final text = _text(item);
    if (text.isNotEmpty) {
      result[key.toString()] = text;
    }
  });
  return result;
}

String _text(Object? value) => value?.toString().trim() ?? '';
