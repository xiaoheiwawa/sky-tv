import '../source/source_id.dart';
import 'source_kind.dart';

class VideoSource {
  const VideoSource({
    required this.sourceId,
    required this.name,
    required this.apiUrl,
    this.kind = SourceKind.maccms,
    this.extend = '',
    this.disabled = false,
    this.sortOrder = 0,
    this.avgLatencyMs = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
  });

  factory VideoSource.create({
    required String name,
    required String apiUrl,
    SourceKind kind = SourceKind.maccms,
    String extend = '',
    bool disabled = false,
  }) {
    final normalizedName = normalizeSourceName(name);
    final normalizedApiUrl = normalizeApiUrl(apiUrl, kind: kind);
    return VideoSource(
      sourceId: buildSourceId(normalizedName, normalizedApiUrl),
      name: normalizedName,
      apiUrl: normalizedApiUrl,
      kind: kind,
      extend: extend.trim(),
      disabled: disabled,
    );
  }

  factory VideoSource.fromJson(Map<String, Object?> json) {
    final name = (json['name'] ?? json['source_name']) as String?;
    final apiUrl = (json['api_url'] ?? json['apiUrl']) as String?;
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('视频源 name 不能为空');
    }
    if (apiUrl == null || apiUrl.trim().isEmpty) {
      throw const FormatException('视频源 api_url 不能为空');
    }
    return VideoSource.create(
      name: name,
      apiUrl: apiUrl,
      kind: SourceKind.fromJson(json['kind']),
      extend: (json['extend'] as String?) ?? '',
      disabled: json['disabled'] == true,
    );
  }

  final String sourceId;
  final String name;
  final String apiUrl;
  final SourceKind kind;
  final String extend;
  final bool disabled;
  final int sortOrder;
  final int avgLatencyMs;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;

  VideoSource copyWith({
    String? sourceId,
    String? name,
    String? apiUrl,
    SourceKind? kind,
    String? extend,
    bool? disabled,
    int? sortOrder,
    int? avgLatencyMs,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
  }) {
    return VideoSource(
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      apiUrl: apiUrl ?? this.apiUrl,
      kind: kind ?? this.kind,
      extend: extend ?? this.extend,
      disabled: disabled ?? this.disabled,
      sortOrder: sortOrder ?? this.sortOrder,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
    );
  }
}
