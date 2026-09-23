import 'package:skytv/core/models/video_source.dart';
import 'package:skytv/core/parser/maccms_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses categories and detail from MacCMS json', () {
    final source = VideoSource.create(
      name: '影视',
      apiUrl: 'https://example.com/api.php/provide/vod',
    );
    final parser = MacCmsParser();

    final categories = parser.parseCategories({
      'class': [
        {'type_id': 1, 'type_name': '电影'},
      ],
    }, source);

    final detail = parser.parseDetail({
      'list': [
        {
          'vod_id': 10,
          'vod_name': '测试影片',
          'vod_pic': 'https://example.com/a.jpg',
          'vod_year': '2026',
          'type_name': '电影',
          'vod_content': '<p>简介</p>',
          'vod_play_from': '线路',
          'vod_play_url': '第1集\$https://example.com/1.m3u8',
        },
      ],
    }, source);

    expect(categories.single.name, '电影');
    expect(detail?.title, '测试影片');
    expect(detail?.description, '简介');
    expect(detail?.playLines.single.episodes.single.title, '第1集');
  });

  test('parses drpy category filters with shared fallback', () {
    final source = VideoSource.create(
      name: '影视',
      apiUrl: 'http://127.0.0.1:5757/api/x',
    );
    final parser = MacCmsParser();

    final categories = parser.parseCategories({
      'class': [
        {'type_id': 'movie', 'type_name': '电影'},
        {'type_id': 'tv', 'type_name': '剧集'},
      ],
      'filters': {
        '*': [
          {
            'key': 'sort',
            'name': '排序',
            'value': [
              {'n': '最新', 'v': ''},
              {'n': '最热', 'v': '83'},
            ],
          },
        ],
        'tv': [
          {
            'key': 'area',
            'name': '地区',
            'value': [
              {'n': '全部', 'v': ''},
              {'n': '国产', 'v': 'cn'},
            ],
          },
        ],
      },
    }, source);

    expect(categories, hasLength(2));
    final movie = categories.firstWhere((item) => item.id == 'movie');
    final tv = categories.firstWhere((item) => item.id == 'tv');
    expect(movie.filters.single.key, 'sort');
    expect(movie.filters.single.options[1].value, '83');
    expect(tv.filters.single.key, 'area');
    expect(tv.filters.single.options[1].value, 'cn');
  });
}
