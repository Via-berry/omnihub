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

  // 推荐题材/找片标签
  final RxList<JavTagPrompt> recommendationTags = <JavTagPrompt>[].obs;

  // 搜索状态
  final TextEditingController searchInputController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool isSearchLoading = false.obs;
  final RxString searchAiComment = ''.obs;
  final RxList<JavItem> searchResults = <JavItem>[].obs;

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
    searchInputController.dispose();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      // 并行拉取真实首屏数据：今日新片、真实高分神作推荐、精翻中字、热门女优、智能标签
      final results = await Future.wait([
        api.fetchExplore(page: 1),
        api.search('高分中字高清佳作'),
        api.search('精翻中文字幕'),
        api.fetchActresses(),
        api.fetchTags(),
      ]);

      final p1Items = results[0] as List<JavItem>;
      final hotSearchResult = results[1] as JavSearchResult;
      final zhSearchResult = results[2] as JavSearchResult;
      final actressList = results[3] as List<JavActress>;
      final tagsList = results[4] as List<JavTagPrompt>;

      if (p1Items.isNotEmpty) {
        nowPlayingItems.value = p1Items;
      }

      if (hotSearchResult.results.isNotEmpty) {
        hotItems.value = hotSearchResult.results;
        // 选用真实高分作品作为轮播大画幅海报
        bannerItems.value = hotSearchResult.results.take(5).toList();
      } else if (p1Items.isNotEmpty) {
        bannerItems.value = p1Items.take(5).toList();
      }

      if (zhSearchResult.results.isNotEmpty) {
        subtitledItems.value = zhSearchResult.results;
      }

      if (actressList.isNotEmpty) {
        actresses.value = actressList;
      }

      if (tagsList.isNotEmpty) {
        recommendationTags.value = tagsList;
      }

      if (bannerItems.isEmpty && hotItems.isEmpty && nowPlayingItems.isEmpty) {
        errorMsg.value = '未能获取到任何数据，请检查后端服务是否正常运行。';
      }
    } catch (e) {
      errorMsg.value = '无法连接到局域网服务 (${api.baseUrl})\n\n'
          '排查建议：\n'
          '1. 手机当前若使用 5G 移动网络，请连接家庭 Wi-Fi\n'
          '2. 若开启了代理/VPN，请确认局域网网段未被代理劫持\n'
          '3. 可点击右上角齿轮修改为内网穿透或公网地址';
      debugPrint('JavController.fetchInitialData error: $e');
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> executeSearch(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    searchQuery.value = query;
    if (searchInputController.text != query) {
      searchInputController.text = query;
    }
    isSearching.value = true;
    isSearchLoading.value = true;
    searchAiComment.value = '';
    searchResults.clear();

    try {
      final res = await api.search(query);
      searchResults.value = res.results;
      searchAiComment.value = res.aiComment ?? '';
    } catch (e) {
      debugPrint('executeSearch error: $e');
    } finally {
      isSearchLoading.value = false;
    }
  }

  void clearSearch() {
    searchInputController.clear();
    searchQuery.value = '';
    isSearching.value = false;
    isSearchLoading.value = false;
    searchResults.clear();
    searchAiComment.value = '';
  }

  Future<void> updateServerUrl(String newUrl) async {
    await api.saveBaseUrl(newUrl);
    await refreshData();
  }

  Future<void> refreshData() async {
    isRefreshing.value = true;
    currentPage.value = 1;
    if (isSearching.value && searchQuery.value.isNotEmpty) {
      await executeSearch(searchQuery.value);
      isRefreshing.value = false;
    } else {
      await fetchInitialData();
    }
  }

  void openDetail(String code) {
    if (code.isEmpty) return;
    Get.toNamed('/jav/detail', parameters: {'code': code});
  }

  void exitJav() {
    Get.offAllNamed('/main', arguments: {'initialIndex': 0});
  }
}
