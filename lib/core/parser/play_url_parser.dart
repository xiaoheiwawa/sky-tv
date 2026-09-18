import '../models/media_models.dart';

List<PlayLine> parsePlayLines(
  String? playFrom,
  String? playUrl, {
  bool allowPlayId = false,
}) {
  if (playUrl == null || playUrl.trim().isEmpty) {
    return const [];
  }

  final names = (playFrom ?? '')
      .split(r'$$$')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  final rawLines = playUrl.split(r'$$$');
  final lines = <PlayLine>[];

  for (var i = 0; i < rawLines.length; i++) {
    final episodes = rawLines[i]
        .split('#')
        .map((raw) => _parseEpisode(raw, allowPlayId))
        .whereType<Episode>()
        .toList();
    if (episodes.isEmpty) {
      continue;
    }
    lines.add(
      PlayLine(
        name: i < names.length ? names[i] : '线路 ${i + 1}',
        flag: i < names.length ? names[i] : '',
        episodes: episodes,
      ),
    );
  }
  return lines;
}

Episode? _parseEpisode(String raw, bool allowPlayId) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  final split = value.indexOf(r'$');
  final hasTitle = split > 0 && split < value.length - 1;
  final title = hasTitle ? value.substring(0, split).trim() : '';
  final url = (hasTitle ? value.substring(split + 1) : value).trim();
  if (url.isEmpty) {
    return null;
  }
  // DS 源的分集值是服务端 play id，不一定是 http 地址。
  if (!allowPlayId && !_isPlayableUrl(url)) {
    return null;
  }
  return Episode(title: title.isEmpty ? '播放' : title, url: url);
}

bool _isPlayableUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
