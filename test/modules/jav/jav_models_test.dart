import 'package:flutter_test/flutter_test.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';

void main() {
  group('JavDetail Model Tests', () {
    test('parses MissAV enriched JSON payload correctly', () {
      final json = {
        'code': 'RCTD-763',
        'title': 'ROCKET 18周年纪念作',
        'synopsis': '这是剧情简介测试内容',
        'cover': 'https://fourhoi.com/rctd-763/cover-n.jpg',
        'preview_url': 'https://fourhoi.com/rctd-763/preview.mp4',
        'release_date': '2026-09-21',
        'duration': '6134',
        'genres': [
          {'id': 'dm156', 'name': '巨乳'},
          {'id': 'dm55', 'name': '4K'},
        ],
        'stars': [
          {'id': 'dm13', 'name': '九井スナオ'},
        ],
        'makers': [
          {'id': 'dm88', 'name': 'ROCKET'},
        ],
        'labels': [
          {'id': 'dm190', 'name': 'ROCKET'},
        ],
        'streams': {
          'hls_master': 'https://surrit.com/uuid/playlist.m3u8',
          'source842': 'https://surrit.com/uuid/720p/video.m3u8',
          'webpage': 'https://missav.ai/rctd-763/ja',
        },
        'online_watch_urls': {
          'MissAV 全网片源': 'https://missav.ai/rctd-763/ja',
        },
        'magnets': [
          {
            'name': 'RCTD-763',
            'magnet': 'magnet:?xt=urn:btih:test',
            'size': '4.30GB',
            'date': '2026-09-22',
            'has_subtitles': false,
            'is_hd': true,
          }
        ],
        'missav': {'available': true, 'slug': 'rctd-763'},
        '_source': 'missav',
      };

      final detail = JavDetail.fromJson(json);

      expect(detail.code, 'RCTD-763');
      expect(detail.title, 'ROCKET 18周年纪念作');
      expect(detail.synopsis, '这是剧情简介测试内容');
      expect(detail.cover, 'https://fourhoi.com/rctd-763/cover-n.jpg');
      expect(detail.previewUrl, 'https://fourhoi.com/rctd-763/preview.mp4');
      expect(detail.maker, 'ROCKET');
      expect(detail.label, 'ROCKET');
      expect(detail.genres, ['巨乳', '4K']);
      expect(detail.structuredGenres.length, 2);
      expect(detail.structuredGenres.first.id, 'dm156');
      expect(detail.structuredGenres.first.name, '巨乳');
      expect(detail.stars.length, 1);
      expect(detail.stars.first.name, '九井スナオ');
      expect(detail.actresses.length, 1);
      expect(detail.actresses.first.name, '九井スナオ');
      expect(detail.streams?.hlsMaster, 'https://surrit.com/uuid/playlist.m3u8');
      expect(detail.streams?.hls720p, 'https://surrit.com/uuid/720p/video.m3u8');
      expect(detail.isMissavAvailable, true);
      expect(detail.magnets.length, 1);
      expect(detail.onlineWatchUrls['MissAV 全网片源'], 'https://missav.ai/rctd-763/ja');
    });

    test('parses legacy JavBus payload gracefully without error', () {
      final json = {
        'code': 'SSIS-834',
        'title': '三上悠亚引退作',
        'cover': 'https://www.javbus.com/pics/cover/ssis_834.jpg',
        'release_date': '2023-08-15',
        'genres': ['单体作品', '巨乳'],
        'actresses': ['三上悠亚'],
        'sample_photos': ['https://pics.dmm.co.jp/sample.jpg'],
        'magnets': [],
        'online_watch_urls': {},
      };

      final detail = JavDetail.fromJson(json);

      expect(detail.code, 'SSIS-834');
      expect(detail.synopsis, isNull);
      expect(detail.streams, isNull);
      expect(detail.genres, ['单体作品', '巨乳']);
      expect(detail.actresses.first.name, '三上悠亚');
      expect(detail.isMissavAvailable, false);
    });

    test('parses JavSettings properly', () {
      final json = {
        'missav_base': 'https://missav.ai',
        'missav_locale': 'ja',
        'allowed_hosts': ['missav.ai', 'fourhoi.com', 'surrit.com'],
        'version': '2.4.0',
      };

      final settings = JavSettings.fromJson(json);

      expect(settings.missavBase, 'https://missav.ai');
      expect(settings.allowedHosts.length, 3);
      expect(settings.allowedHosts.contains('fourhoi.com'), true);
    });

    test('parses JavHomeRecommendations properly', () {
      final json = {
        'recommended': [
          {
            'code': 'RCTD-763',
            'title': 'ROCKET 18周年纪念作',
            'cover': 'https://fourhoi.com/rctd-763/cover-n.jpg',
            'duration': '100分鐘',
            'has_chinese_subtitle': true,
            'is_hd': true,
          }
        ],
        'segments': [
          {
            'name': '巨乳',
            'items': [
              {
                'code': 'MKMP-522',
                'title': '巨乳作品标题',
                'cover': 'https://fourhoi.com/mkmp-522/cover-n.jpg',
              }
            ]
          }
        ],
        '_source': 'missav_recombee'
      };

      final homeRec = JavHomeRecommendations.fromJson(json);

      expect(homeRec.recommended.length, 1);
      expect(homeRec.recommended.first.code, 'RCTD-763');
      expect(homeRec.recommended.first.hasSubtitles, false);
      expect(homeRec.segments.length, 1);
      expect(homeRec.segments.first.name, '巨乳');
      expect(homeRec.segments.first.items.first.code, 'MKMP-522');
      expect(homeRec.source, 'missav_recombee');
    });

    test('parses standalone JavStreams response payload properly', () {
      final json = {
        'hls_master': 'https://surrit.com/test-id/playlist.m3u8',
        'source842': 'https://surrit.com/test-id/720p/video.m3u8',
        'webpage': 'https://missav.ai/rctd-763/ja',
      };

      final streams = JavStreams.fromJson(json);

      expect(streams.hlsMaster, 'https://surrit.com/test-id/playlist.m3u8');
      expect(streams.hls720p, 'https://surrit.com/test-id/720p/video.m3u8');
      expect(streams.webpage, 'https://missav.ai/rctd-763/ja');
    });
  });
}

