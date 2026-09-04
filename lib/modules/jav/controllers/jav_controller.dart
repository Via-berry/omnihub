import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';

class JavController extends GetxController {
  final JavApiService api = JavApiService();

  // 内存数据快照（跨页面与生命周期保活，零等待秒开）
  static final List<JavItem> _cachedNowPlaying = [];
  static final List<JavItem> _cachedHot = [];
  static final List<JavItem> _cachedSubtitled = [];
  static final List<JavActress> _cachedActresses = [];
  static final List<JavTagPrompt> _cachedTags = [];

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

  // 请求取消令牌
  CancelToken? _searchCancelToken;
  CancelToken? _fetchCancelToken;

  @override
  void onInit() {
    super.onInit();
    bannerPageController = PageController();

    // 优先灌入内存快照数据，实现 0ms 瞬间渲染
    if (_cachedNowPlaying.isNotEmpty) {
      nowPlayingItems.assignAll(_cachedNowPlaying);
      bannerItems.assignAll(_cachedNowPlaying.take(5));
      if (_cachedHot.isNotEmpty) hotItems.assignAll(_cachedHot);
      if (_cachedSubtitled.isNotEmpty) subtitledItems.assignAll(_cachedSubtitled);
      if (_cachedActresses.isNotEmpty) actresses.assignAll(_cachedActresses);
      if (_cachedTags.isNotEmpty) recommendationTags.assignAll(_cachedTags);
      isLoading.value = false;
    }

    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await api.initBaseUrl();
    await fetchInitialData();
  }

  @override
  void onClose() {
    _searchCancelToken?.cancel();
    _fetchCancelToken?.cancel();
    bannerPageController.dispose();
    searchInputController.dispose();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    if (nowPlayingItems.isEmpty) {
      isLoading.value = true;
    }
    errorMsg.value = '';

    _fetchCancelToken?.cancel();
    _fetchCancelToken = CancelToken();

    try {
      // 阶段一：毫秒级极速首屏（并行拉取轻量实时数据：探索流、女优名录、智能标签）
      final fastResults = await Future.wait([
        api.fetchExplore(page: 1, cancelToken: _fetchCancelToken),
        api.fetchActresses(cancelToken: _fetchCancelToken),
        api.fetchTags(cancelToken: _fetchCancelToken),
      ]);

      final p1Items = fastResults[0] as List<JavItem>;
      final actressList = fastResults[1] as List<JavActress>;
      final tagsList = fastResults[2] as List<JavTagPrompt>;

      if (p1Items.isNotEmpty) {
        nowPlayingItems.assignAll(p1Items);
        bannerItems.assignAll(p1Items.take(5));
        _cachedNowPlaying.assignAll(p1Items);
      }

      if (actressList.isNotEmpty) {
        actresses.assignAll(actressList);
        _cachedActresses.assignAll(actressList);
      }

      if (tagsList.isNotEmpty) {
        recommendationTags.assignAll(tagsList);
        _cachedTags.assignAll(tagsList);
      }

      // 首屏关键数据到位，立即释放全屏等待状态
      isLoading.value = false;
      isRefreshing.value = false;

      // 阶段二：后台静默填充其余专区（无需全屏转圈，不阻塞用户操作）
      _fetchBackgroundCurations();
    } catch (e) {
      if (nowPlayingItems.isEmpty) {
        errorMsg.value = '无法连接到局域网服务 (${api.baseUrl})\n\n'
            '排查建议：\n'
            '1. 手机当前若使用 5G 移动网络，请连接家庭 Wi-Fi\n'
            '2. 若开启了代理/VPN，请确认局域网网段未被代理劫持\n'
            '3. 可点击右上角齿轮修改为内网穿透或公网地址';
      }
      debugPrint('JavController.fetchInitialData error: $e');
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> _fetchBackgroundCurations() async {
    try {
      // 后台静默拉取第二页作为精选和中字推荐填充
      final p2Items = await api.fetchExplore(page: 2, cancelToken: _fetchCancelToken);
      if (p2Items.isNotEmpty) {
        if (hotItems.isEmpty) {
          hotItems.assignAll(p2Items);
          _cachedHot.assignAll(p2Items);
        }
        final zh = p2Items.where((e) => e.hasSubtitles).toList();
        if (zh.isNotEmpty && subtitledItems.isEmpty) {
          subtitledItems.assignAll(zh);
          _cachedSubtitled.assignAll(zh);
        }
      }
    } catch (_) {}
  }

  Future<void> executeSearch(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    // 取消上一轮未完成的搜索网络请求，防止堆积
    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();

    searchQuery.value = query;
    if (searchInputController.text != query) {
      searchInputController.text = query;
    }
    isSearching.value = true;
    isSearchLoading.value = true;
    searchAiComment.value = '';
    searchResults.clear();

    try {
      final res = await api.search(query, cancelToken: _searchCancelToken);
      if (searchQuery.value == query) {
        searchResults.assignAll(res.results);
        searchAiComment.value = res.aiComment ?? '';
      }
    } catch (e) {
      debugPrint('executeSearch error: $e');
    } finally {
      if (searchQuery.value == query) {
        isSearchLoading.value = false;
      }
    }
  }

  void clearSearch() {
    _searchCancelToken?.cancel();
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
