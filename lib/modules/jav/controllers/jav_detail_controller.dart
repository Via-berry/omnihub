import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class JavDetailController extends GetxController {
  final JavApiService api = JavApiService();

  late final String code;
  final Rxn<JavDetail> detail = Rxn<JavDetail>();
  final RxBool isLoading = true.obs;
  final RxString errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    code = (params['code'] ?? '').trim();
    if (code.isNotEmpty) {
      loadDetail();
    } else {
      errorMsg.value = '未指定有效番号';
      isLoading.value = false;
    }
  }

  Future<void> loadDetail() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final res = await api.fetchDetail(code);
      if (res != null) {
        detail.value = res;
      } else {
        errorMsg.value = '未能获取到番号 $code 的详情';
      }
    } catch (e) {
      errorMsg.value = '连接 NAS 服务异常，请确认网络环境';
      debugPrint('JavDetailController.loadDetail error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 复制单个磁力链接
  void copyMagnet(JavMagnet magnet) {
    if (magnet.magnet.isEmpty) return;
    Clipboard.setData(ClipboardData(text: magnet.magnet));
    ToastUtil.success('磁力链接已复制到剪贴板！');
  }

  /// 复制最佳磁力链接 (优先中字，其次按体积最大排序)
  void copyBestMagnet() {
    final d = detail.value;
    if (d == null || d.magnets.isEmpty) {
      ToastUtil.info('暂无可用磁力链接');
      return;
    }

    final sorted = List<JavMagnet>.from(d.magnets);
    sorted.sort((a, b) {
      if (a.hasSubtitles != b.hasSubtitles) {
        return a.hasSubtitles ? -1 : 1;
      }
      final sizeA = a.sizeMb ?? 0;
      final sizeB = b.sizeMb ?? 0;
      return sizeB.compareTo(sizeA);
    });

    final best = sorted.first;
    Clipboard.setData(ClipboardData(text: best.magnet));
    ToastUtil.success('已复制最佳磁力（${best.name.isNotEmpty ? best.name : best.size}）！');
  }

  void openPlayer(String url) {
    if (url.isEmpty) return;
    Get.toNamed('/jav/player', parameters: {'url': url, 'title': detail.value?.title ?? code});
  }

  void exitJav() {
    Get.offAllNamed('/main', arguments: {'initialIndex': 0});
  }
}
