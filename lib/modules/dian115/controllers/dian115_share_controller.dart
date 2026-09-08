import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class Dian115ShareController extends GetxController {
  final int? tmdbId;
  final String mediaType;
  final int? initialSeason;
  final String mediaTitle;

  Dian115ShareController({
    this.tmdbId,
    this.mediaType = 'movie',
    this.initialSeason,
    this.mediaTitle = '',
  });

  final Dian115Service service = Dian115Service.to;

  final RxBool isLoading = true.obs;
  final RxString errorMsg = ''.obs;
  final Rx<Dian115SharesResponse?> sharesResponse = Rx<Dian115SharesResponse?>(null);
  final RxList<Dian115ShareItem> allShares = <Dian115ShareItem>[].obs;

  final RxInt userPoints = 0.obs;
  final RxBool isOnline = false.obs;
  final RxBool isSigningIn = false.obs;
  final RxBool isUnlocking = false.obs;

  // 筛选器状态
  final RxString filterResolution = 'all'.obs; // 'all', '4K', '1080P'
  final RxString filterKind = 'all'.obs; // 'all', '115', 'offline'
  final RxBool filterOnlyChineseSub = false.obs;
  final RxInt filterSeason = (-1).obs; // -1 表示全部，>=0 表示指定季
  final RxString sortBy = 'size_desc'.obs; // 'size_desc', 'use_desc', 'date_desc'

  @override
  void onInit() {
    super.onInit();
    if (initialSeason != null && initialSeason! >= 0) {
      filterSeason.value = initialSeason!;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _refreshStatus();
    await fetchShares();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await service.getStatus();
      isOnline.value = status.service == 'online';
      userPoints.value = status.points;
    } catch (_) {
      isOnline.value = false;
    }
  }

  Future<void> fetchShares() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      int? effectiveTmdbId = tmdbId;

      // 1. 如果没有 tmdb_id，先尝试用标题全局检索匹配 tmdb_id
      if ((effectiveTmdbId == null || effectiveTmdbId <= 0) && mediaTitle.trim().isNotEmpty) {
        try {
          final searchResult = await service.searchMedia(mediaTitle.trim());
          if (searchResult.results.isNotEmpty) {
            effectiveTmdbId = searchResult.results.first.tmdbId;
          }
        } catch (_) {}
      }

      if (effectiveTmdbId == null || effectiveTmdbId <= 0) {
        errorMsg.value = '未找到该影视对应的 TMDB 资源标识';
        isLoading.value = false;
        return;
      }

      final resp = await service.getShares(
        tmdbId: effectiveTmdbId,
        mediaType: mediaType,
        season: filterSeason.value >= 0 ? filterSeason.value : null,
      );

      sharesResponse.value = resp;
      allShares.assignAll(resp.shares);
    } catch (e) {
      errorMsg.value = '获取网盘资源失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  List<Dian115ShareItem> get filteredShares {
    var list = allShares.toList();

    // 1. 分辨率筛选
    if (filterResolution.value != 'all') {
      final target = filterResolution.value.toUpperCase();
      list = list.where((item) {
        final res = item.resolution.toUpperCase();
        if (target == '4K') {
          return res.contains('4K') || res.contains('2160');
        } else if (target == '1080P') {
          return res.contains('1080');
        }
        return res.contains(target);
      }).toList();
    }

    // 2. 渠道类型筛选
    if (filterKind.value != 'all') {
      if (filterKind.value == '115') {
        list = list.where((item) => item.is115).toList();
      } else if (filterKind.value == 'offline') {
        list = list.where((item) => item.isMagnet).toList();
      }
    }

    // 3. 中文字幕筛选
    if (filterOnlyChineseSub.value) {
      list = list.where((item) => item.hasChineseSubtitle).toList();
    }

    // 4. 季度筛选 (当在客户端二次过滤时)
    if (filterSeason.value >= 0) {
      list = list.where((item) {
        if (item.season == filterSeason.value) return true;
        if (item.seasons.isNotEmpty) {
          final parts = item.seasons.split(RegExp(r'[, -]'));
          return parts.contains(filterSeason.value.toString());
        }
        return true;
      }).toList();
    }

    // 5. 排序
    if (sortBy.value == 'size_desc') {
      list.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
    } else if (sortBy.value == 'use_desc') {
      list.sort((a, b) => b.useCount.compareTo(a.useCount));
    } else if (sortBy.value == 'date_desc') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  Future<Dian115UnlockResult?> unlock(Dian115ShareItem item) async {
    isUnlocking.value = true;
    try {
      HapticFeedback.mediumImpact();
      final result = await service.unlockShare(item.id);
      if (result.isSuccess) {
        userPoints.value = (userPoints.value - item.unlockCost).clamp(0, 999999);
        ToastUtil.success('解锁成功！已获得转存链接');
        return result;
      } else {
        ToastUtil.error('解锁失败：${result.code}');
        return null;
      }
    } catch (e) {
      ToastUtil.error('解锁请求失败：$e');
      return null;
    } finally {
      isUnlocking.value = false;
    }
  }

  Future<void> signin() async {
    if (isSigningIn.value) return;
    isSigningIn.value = true;
    try {
      HapticFeedback.selectionClick();
      final res = await service.signin();
      final added = res['points_added'] as int? ?? 5;
      userPoints.value += added;
      ToastUtil.success('签到成功！积分 +$added');
    } catch (e) {
      ToastUtil.info('今日已完成签到');
    } finally {
      isSigningIn.value = false;
    }
  }
}
