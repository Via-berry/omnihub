import 'package:flutter_test/flutter_test.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/pansou/models/pansou_models.dart';

void main() {
  // 磁力链接普遍携带 115 自家 tracker，历史上被误判成 115 分享后，
  // 整条磁力被当作 share_url 提交，115 把它落成一个 txt 文件。
  const magnetWith115Tracker =
      'magnet:?xt=urn:btih:f3e28d940d98b8ce1e9f0b3dd11782e4115'
      '&dn=Some.Movie.2026.1080p&tr=udp%3A%2F%2Ftracker.115.com%3A8090%2Fannounce';

  group('PansouItemType.fromRaw', () {
    test('磁力链接不会被 115 tracker 域名误判为 115 分享', () {
      expect(PansouItemType.fromRaw('magnet', magnetWith115Tracker),
          PansouItemType.magnet);
      expect(PansouItemType.fromRaw('', magnetWith115Tracker),
          PansouItemType.magnet);
      expect(PansouItemType.fromRaw('0', magnetWith115Tracker),
          PansouItemType.magnet);
    });

    test('电驴链接同样优先于域名判定', () {
      expect(PansouItemType.fromRaw('115', 'ed2k://|file://a.txt|/a.txt'),
          PansouItemType.ed2k);
      expect(PansouItemType.fromRaw('', 'ed2k://|file://a.txt|/a.txt'),
          PansouItemType.ed2k);
    });

    test('真实 115 分享链接仍识别为 115', () {
      expect(PansouItemType.fromRaw('115', 'https://115.com/s/abc'),
          PansouItemType.pan115);
      expect(PansouItemType.fromRaw('', 'https://wws.anxia.com/s/abc'),
          PansouItemType.pan115);
      expect(PansouItemType.fromRaw('', 'https://115cdn.com/x/y'),
          PansouItemType.pan115);
    });

    test('其他网盘与未知来源保持不变', () {
      expect(PansouItemType.fromRaw('quark', 'https://pan.quark.cn/s/abc'),
          PansouItemType.quark);
      expect(PansouItemType.fromRaw('baidu', 'https://pan.baidu.com/s/abc'),
          PansouItemType.baidu);
      expect(PansouItemType.fromRaw('', 'https://example.com/x'),
          PansouItemType.other);
    });
  });

  group('PansouItem.fromMergedJson', () {
    test('带 115 tracker 的磁力走离线下载而不是分享转存', () {
      final item = PansouItem.fromMergedJson(
        rawType: 'magnet',
        json: {'url': magnetWith115Tracker, 'note': 'Some.Movie.2026', 'source': 'Pansou'},
      );

      expect(item.is115, isFalse);
      expect(item.isOfflineDownload, isTrue);
      expect(item.url, magnetWith115Tracker);
      expect(item.offlineUrlCount, 1);
    });

    test('提取到的离线链接会剔除空白并按出现顺序去重', () {
      final item = PansouItem.fromMergedJson(
        rawType: 'magnet',
        json: {
          'url': '  ${magnetWith115Tracker}  ',
          'urls': [magnetWith115Tracker, 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567'],
        },
      );

      expect(item.hasMultipleUrls, isTrue);
      expect(item.urls.length, 2);
      expect(item.urls.first, magnetWith115Tracker);
    });
  });

  group('extractAllOfflineUrls', () {
    test('同一行内的多条磁力全部提取', () {
      final result = extractAllOfflineUrls(
        rawNote:
            '$magnetWith115Tracker magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      );

      expect(result.length, 2);
    });
  });

  group('提取码回退', () {
    const shareUrlWithQueryCode =
        'https://115cdn.com/s/swsg4m13zrk?password=t58d';

    test('extractReceiveCode 从 query 里取 password / pwd / pass', () {
      expect(extractReceiveCode(shareUrlWithQueryCode), 't58d');
      expect(extractReceiveCode('https://pan.quark.cn/s/abc?pwd=abc1'), 'abc1');
      expect(extractReceiveCode('https://pan.quark.cn/s/abc?pass=zzz'), 'zzz');
      expect(extractReceiveCode('https://115.com/s/abc'), '');
      expect(extractReceiveCode('not a url'), '');
    });

    test('password 字段为空时从链接 query 补出来', () {
      final item = PansouItem.fromMergedJson(
        rawType: '115',
        json: {
          'url': shareUrlWithQueryCode,
          'note': '年会不能停！2 (2026)',
          'source': 'Pansou',
        },
      );

      expect(item.is115, isTrue);
      expect(item.password, 't58d');
    });

    test('password 字段已有值时不被链接 query 覆盖', () {
      final item = PansouItem.fromMergedJson(
        rawType: '115',
        json: {
          'url': shareUrlWithQueryCode,
          'password': 'fromfield',
        },
      );

      expect(item.password, 'fromfield');
    });
  });
}
