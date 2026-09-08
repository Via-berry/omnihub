import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/widgets/dian115_verify_sheet.dart';
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
  final RxBool isTodaySigned = false.obs;
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
      isTodaySigned.value = status.isTodaySigned;
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

  Future<Dian115UnlockResult?> unlock(
    Dian115ShareItem item, {
    BuildContext? context,
  }) async {
    // 1. 若本地已缓存或服务端已标明该资源的有效解锁凭据，直接返回
    if (service.isUnlocked(item.id)) {
      final cached = service.getUnlockedInfo(item.id);
      if (cached != null && cached.isSuccess) {
        return cached;
      }
    }
    if (item.isUnlocked && (item.shareUrl.isNotEmpty || item.magnetUrl.isNotEmpty)) {
      final cached = Dian115UnlockResult(
        code: 'ok',
        shareUrl: item.shareUrl,
        receiveCode: item.receiveCode,
        magnetUrl: item.magnetUrl,
        pointsCost: item.unlockCost,
      );
      await service.saveUnlockedInfo(item.id, cached);
      return cached;
    }

    isUnlocking.value = true;
    try {
      HapticFeedback.mediumImpact();
      final targetSeason =
          filterSeason.value >= 0 ? filterSeason.value : (initialSeason ?? 0);
      // 2. 先尝试服务端直接静默解锁（若已解锁或可免检，服务端直接返回链接）
      final result = await service.unlockShare(
        item.id,
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: targetSeason,
      );
      if (result.isSuccess) {
        await _refreshStatus();
        ToastUtil.success('解锁成功！已获得转存链接');
        return result;
      }

      // 3. 若触发人机安全验证，拉起应用内原生验证弹窗无缝过检
      if (context != null && context.mounted) {
        ToastUtil.info('此资源需进行安全验证，请在弹窗中轻触验证');
        final verifiedResult = await Dian115VerifySheet.show(
          context,
          item: item,
          tmdbId: tmdbId,
          mediaType: mediaType,
          season: filterSeason.value >= 0 ? filterSeason.value : (initialSeason ?? 0),
        );
        if (verifiedResult != null && verifiedResult.isSuccess) {
          await service.saveUnlockedInfo(item.id, verifiedResult);
          await _refreshStatus();
          return verifiedResult;
        }
      }

      if (!result.isSuccess) {
        ToastUtil.error(result.isTurnstileRequired
            ? '人机安全验证未完成'
            : '解锁失败：${result.code}');
      }
      return null;
    } catch (e) {
      if (context != null && context.mounted) {
        final verifiedResult = await Dian115VerifySheet.show(
          context,
          item: item,
          tmdbId: tmdbId,
          mediaType: mediaType,
          season: filterSeason.value >= 0 ? filterSeason.value : (initialSeason ?? 0),
        );
        if (verifiedResult != null && verifiedResult.isSuccess) {
          await service.saveUnlockedInfo(item.id, verifiedResult);
          await _refreshStatus();
          return verifiedResult;
        }
      }
      ToastUtil.error('解锁请求异常：$e');
      return null;
    } finally {
      isUnlocking.value = false;
    }
  }

  /// 确认解锁并一键自动转存至 115 对应目录
  Future<void> unlockAndTransfer(BuildContext context, Dian115ShareItem item) async {
    // 1. 积分余额检查
    if (item.unlockCost > 0 && userPoints.value < item.unlockCost) {
      ToastUtil.error('积分不足！当前余额 ${userPoints.value} 分，需 ${item.unlockCost} 分，请先签到获取积分');
      return;
    }

    final targetFolder = Pan115Service.to.getTargetFolderName(mediaType);
    final targetCid = Pan115Service.to.getTargetCid(mediaType);

    // 2. 确认对话框
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('确认解锁并转存'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.unlockCost > 0
                    ? '确认消耗 ${item.unlockCost} 积分获取此片源并自动保存？'
                    : '此为免费片源，确认获取并自动保存？',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '保存目标: $targetFolder',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '目录 CID: $targetCid',
                      style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey),
                    ),
                  ],
                ),
              ),
              if (item.unlockCost > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '当前余额: ${userPoints.value} 积分 (解锁后剩余: ${(userPoints.value - item.unlockCost).clamp(0, 999999)} 积分)',
                  style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认解锁转存'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 3. 执行解锁（含安全验证重试机制）
    final unlockResult = await unlock(item, context: context);
    if (unlockResult == null || !unlockResult.isSuccess) {
      return;
    }

    // 4. 解锁成功后立即无缝转存至 115
    await transferToPan115(
      shareUrl: unlockResult.shareUrl,
      receiveCode: unlockResult.receiveCode,
      magnetUrl: unlockResult.magnetUrl,
    );
  }

  Future<bool> transferToPan115({
    String? shareUrl,
    String? receiveCode,
    String? magnetUrl,
  }) async {
    try {
      HapticFeedback.mediumImpact();
      ToastUtil.info('正在请求 115 转存...');
      final res = await Pan115Service.to.transfer(
        mediaType: mediaType,
        shareUrl: shareUrl,
        receiveCode: receiveCode,
        magnetUrl: magnetUrl,
      );
      final isSuccess = res['success'] == true;
      final msg = res['msg']?.toString() ?? (isSuccess ? '转存成功' : '转存失败');
      if (isSuccess) {
        ToastUtil.success(msg);
      } else {
        ToastUtil.error(msg);
      }
      return isSuccess;
    } catch (e) {
      ToastUtil.error('转存发生异常: $e');
      return false;
    }
  }

  Future<void> signin() async {
    if (isTodaySigned.value) {
      ToastUtil.info('今日已完成签到');
      return;
    }
    if (isSigningIn.value) return;
    isSigningIn.value = true;
    try {
      HapticFeedback.selectionClick();
      final res = await service.signin();
      await _refreshStatus();
      if (res['code'] == 'already_signed') {
        ToastUtil.info('今日已完成签到');
      } else {
        final added = res['points_added'] as int? ?? 5;
        ToastUtil.success('签到成功！积分 +$added，当前余额 ${userPoints.value}');
      }
    } catch (e) {
      await _refreshStatus();
      ToastUtil.info('今日已完成签到');
    } finally {
      isSigningIn.value = false;
    }
  }
}
