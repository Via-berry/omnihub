import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';

class JavController extends GetxController {
  final JavApiService api = JavApiService();

  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMsg = ''.obs;

  // 顶部 Banner 数据
  final RxList<JavItem> bannerItems = <JavItem>[].obs;
  final RxInt bannerPageIndex = 0.obs;
  late final PageController bannerPageController;

  // 分组数据
  final RxList<JavItem> nowPlayingItems = <JavItem>[].obs;
  final RxList<JavItem> hotItems = <JavItem>[].obs;
  final RxList<JavItem> subtitledItems = <JavItem>[].obs;
  final RxList<JavActress> actresses = <JavActress>[].obs;

  // 分页控制
  final RxInt currentPage = 1.obs;
  final RxBool hasMore = true.obs;
  final RxBool isLoadingMore = false.obs;

  @override
  void onInit() {
    super.onInit();
    bannerPageController = PageController();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await api.initBaseUrl();
    await fetchInitialData();
  }

  @override
  void onClose() {
    bannerPageController.dispose();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      // 并行拉取首屏数据
      final results = await Future.wait([
        api.fetchExplore(page: 1),
        api.fetchExplore(page: 2),
        api.fetchExplore(page: 1, magnetType: 'zh'),
        api.fetchActresses(),
      ]);

      final p1Items = results[0] as List<JavItem>;
      final p2Items = results[1] as List<JavItem>;
      final zhItems = results[2] as List<JavItem>;
      final actressList = results[3] as List<JavActress>;

      if (p1Items.isNotEmpty) {
        // 取前 5 个做 Banner 轮播
        bannerItems.value = p1Items.take(5).toList();
        // 其余及第 1 页全部做今日发行
        nowPlayingItems.value = p1Items;
      }

      if (p2Items.isNotEmpty) {
        hotItems.value = p2Items;
      }

      if (zhItems.isNotEmpty) {
        subtitledItems.value = zhItems;
      }

      if (actressList.isNotEmpty) {
        actresses.value = actressList;
      }

      if (bannerItems.isEmpty && hotItems.isEmpty) {
        errorMsg.value = '未能获取到任何数据，请检查后端服务是否正常运行。';
      }
    } catch (e) {
      errorMsg.value = '无法连接到局域网服务 (${api.baseUrl})\n\n'
          '排查建议：\n'
          '1. 手机当前若使用 5G 移动网络，请连接家庭 Wi-Fi\n'
          '2. 若开启了代理/VPN，请确认局域网网段未被代理劫持\n'
          '3. 可点击左上角齿轮修改为内网穿透或公网地址';
      debugPrint('JavController.fetchInitialData error: $e');
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> updateServerUrl(String newUrl) async {
    await api.saveBaseUrl(newUrl);
    await refreshData();
  }

  Future<void> refreshData() async {
    isRefreshing.value = true;
    currentPage.value = 1;
    await fetchInitialData();
  }

  void openDetail(String code) {
    if (code.isEmpty) return;
    Get.toNamed('/jav/detail', parameters: {'code': code});
  }

  void exitJav() {
    Get.offAllNamed('/dashboard');
  }
}
