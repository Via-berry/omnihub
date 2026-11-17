import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JavSafeService extends GetxService {
  static JavSafeService get to {
    if (!Get.isRegistered<JavSafeService>()) {
      return Get.put(JavSafeService(), permanent: true);
    }
    return Get.find<JavSafeService>();
  }

  static const String _storageKey = 'jav_safe_mode_enabled';

  // 默认开启脱敏避人模式，保障首次进入与公共场景的隐私安全
  final RxBool isSafeMode = true.obs;

  // 临时透视的番号集合（长按单张卡片临时解密）
  final RxSet<String> peekingCodes = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_storageKey)) {
        isSafeMode.value = prefs.getBool(_storageKey) ?? true;
      } else {
        // 初次未设置过时，默认为开启脱敏
        isSafeMode.value = true;
      }
    } catch (_) {}
  }

  Future<void> toggleSafeMode() async {
    HapticFeedback.mediumImpact();
    isSafeMode.toggle();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, isSafeMode.value);
    } catch (_) {}
  }

  bool isItemBlurred(String code) {
    if (!isSafeMode.value) return false;
    // 如果该番号正在被长按临时透视，则不模糊
    if (peekingCodes.contains(code)) return false;
    return true;
  }

  void startPeeking(String code) {
    if (code.isEmpty) return;
    HapticFeedback.selectionClick();
    peekingCodes.add(code);
  }

  void stopPeeking(String code) {
    if (code.isEmpty) return;
    peekingCodes.remove(code);
  }
}
