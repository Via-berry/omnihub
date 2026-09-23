import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/modules/pansou/models/pansou_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validMagnet =
      'magnet:?xt=urn:btih:f3e28d940d98b8ce1e9f0b3dd11782e411500000';
  const validMagnetBase32 =
      'magnet:?xt=urn:btih:ABCDEFGH234567ABCDEFGH234567ABC2';
  // 盘搜真实返回过的形态：btih 只有 35 位（正常应为 40 位十六进制）
  const truncatedMagnet =
      'magnet:?xt=urn:btih:f3e28d940d98b8ce1e9f0b3dd11782e4115'
      '&dn=Some.Movie.2026.1080p&tr=udp%3A%2F%2Ftracker.115.com%3A8090%2Fannounce';
  const bareText = 'swsaoay36l0';

  group('isValidMagnetLink', () {
    test('40 位十六进制 btih 有效', () {
      expect(isValidMagnetLink(validMagnet), isTrue);
    });

    test('32 位 base32 btih 有效', () {
      expect(isValidMagnetLink(validMagnetBase32), isTrue);
    });

    test('被截断的 btih 无效', () {
      expect(isValidMagnetLink(truncatedMagnet), isFalse);
    });

    test('无 xt 的磁力不做拦截', () {
      expect(isValidMagnetLink('magnet:?dn=only-name'), isTrue);
    });
  });

  group('isOfflineFileUrl', () {
    test('http/https 直链可接受', () {
      expect(isOfflineFileUrl('https://example.com/a.torrent'), isTrue);
      expect(isOfflineFileUrl('HTTP://example.com/a.torrent'), isTrue);
    });

    test('纯文本不可接受', () {
      expect(isOfflineFileUrl(bareText), isFalse);
    });
  });

  group('collectOfflineUrls', () {
    test('完整磁力通过，资源编号被丢弃', () {
      final result = collectOfflineUrls([bareText, validMagnet]);

      expect(result.validUrls, [validMagnet]);
      expect(result.droppedTexts, [bareText]);
      expect(result.invalidMagnets, isEmpty);
    });

    test('截断磁力不提交，并在提示里报出来', () {
      final result = collectOfflineUrls([truncatedMagnet]);

      expect(result.validUrls, isEmpty);
      expect(result.invalidMagnets, [truncatedMagnet]);
      expect(result.rejectedNote, contains('info-hash 不完整 1 条'));
    });

    test('混在一段文本里的多条磁力全部提取', () {
      final result = collectOfflineUrls(
        ['$truncatedMagnet magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567'],
      );

      expect(result.validUrls, [
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      ]);
      expect(result.invalidMagnets, [truncatedMagnet]);
    });

    test('重复链接去重', () {
      final result = collectOfflineUrls([validMagnet, validMagnet]);

      expect(result.validUrls, [validMagnet]);
    });

    test('全部无效时没有可提交链接', () {
      final result = collectOfflineUrls([bareText]);

      expect(result.validUrls, isEmpty);
      expect(result.hasRejected, isTrue);
    });
  });

  group('extractAllOfflineUrls 的 offlineOnly', () {
    test('offlineOnly 时丢弃资源编号，只收磁力', () {
      final result = extractAllOfflineUrls(
        rawUrls: [bareText, truncatedMagnet],
        rawUrl: truncatedMagnet,
        rawNote: 'Some.Movie.2026',
        offlineOnly: true,
      );

      expect(result, [truncatedMagnet]);
    });

    test('非 offlineOnly 保留兜底行为，裸分享码不被丢掉', () {
      final result = extractAllOfflineUrls(
        rawUrls: ['abc123'],
        rawUrl: 'abc123',
        offlineOnly: false,
      );

      expect(result, ['abc123']);
    });
  });

  group('磁力分类不受 hash 完整性影响', () {
    test('截断磁力仍识别为磁力，不会退回 115 分享判定', () {
      final item = PansouItem.fromMergedJson(
        rawType: 'magnet',
        json: {
          'url': truncatedMagnet,
          'urls': [bareText, truncatedMagnet],
          'note': 'Some.Movie.2026',
          'source': 'Pansou',
        },
      );

      expect(item.is115, isFalse);
      expect(item.isMagnet, isTrue);
      expect(item.isOfflineDownload, isTrue);
      // 资源编号不会进入 urls，也不会成为主链接
      expect(item.url, truncatedMagnet);
      expect(item.offlineUrlCount, 1);
    });
  });
}
