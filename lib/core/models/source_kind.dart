/// 影视源协议类型。
enum SourceKind {
  /// MacCMS V10 JSON 接口（`api.php/provide/vod`）。
  maccms,

  /// drpy-node（DS/T4）接口 `/api/<名称>`，规则由服务端执行。
  ds;

  static SourceKind fromJson(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return switch (text) {
      'ds' || 't4' || 'drpy' || 'drpys' => SourceKind.ds,
      _ => SourceKind.maccms,
    };
  }

  String get label => switch (this) {
    SourceKind.maccms => 'MacCMS',
    SourceKind.ds => 'DS',
  };
}
