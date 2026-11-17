import 'package:flutter_test/flutter_test.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dian115Service 解锁缓存 TTL', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Dian115UnlockResult resultWithAge(Duration age) => Dian115UnlockResult(
          code: 'ok',
          shareUrl: 'https://115.com/s/abc',
          receiveCode: '1234',
          unlockedAtTimestamp:
              DateTime.now().subtract(age).millisecondsSinceEpoch,
        );

    test('新鲜缓存视为已解锁', () {
      final service = Dian115Service();
      service.unlockedMap[1] = resultWithAge(const Duration(hours: 1));

      expect(service.isUnlocked(1), isTrue);
      expect(service.getUnlockedInfo(1), isNotNull);
    });

    test('超过 TTL 的缓存被剔除且不再返回', () {
      final service = Dian115Service();
      service.unlockedMap[1] = resultWithAge(
        Dian115Service.unlockedCacheTtl + const Duration(hours: 1),
      );

      expect(service.isUnlocked(1), isFalse);
      expect(service.getUnlockedInfo(1), isNull);
      expect(service.unlockedMap.containsKey(1), isFalse);
    });

    test('无时间戳的旧版缓存仍视为有效', () {
      final service = Dian115Service();
      service.unlockedMap[1] = const Dian115UnlockResult(
        code: 'ok',
        shareUrl: 'https://115.com/s/abc',
      );

      expect(service.isUnlocked(1), isTrue);
    });

    test('saveUnlockedInfo 为无时间戳结果补打时间戳', () async {
      final service = Dian115Service();
      await service.saveUnlockedInfo(
        7,
        const Dian115UnlockResult(
          code: 'ok',
          shareUrl: 'https://115.com/s/abc',
        ),
      );

      expect(service.unlockedMap[7]?.unlockedAtTimestamp, isNotNull);
      expect(service.isUnlocked(7), isTrue);
    });
  });

  group('Pan115Service.maskCookie', () {
    test('值被脱敏且保留键名', () {
      final masked =
          Pan115Service.maskCookie('UID=123456789; CID=abcdef; SEID=zzz');
      expect(masked, 'UID=12***; CID=ab***; SEID=zz***');
    });

    test('空串原样返回', () {
      expect(Pan115Service.maskCookie(''), '');
      expect(Pan115Service.maskCookie('   '), '');
    });

    test('短值与无等号片段不越界', () {
      expect(Pan115Service.maskCookie('KID=ab'), 'KID=ab***');
      expect(Pan115Service.maskCookie('bare'), 'bare');
    });
  });
}
