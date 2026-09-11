import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/widgets/dian115_transfer_confirm_sheet.dart';
import 'package:moviepilot_mobile/modules/pansou/models/pansou_models.dart';
import 'package:moviepilot_mobile/modules/pansou/services/pansou_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class PansouShareController extends GetxController {
  PansouShareController({
    this.tmdbId,
    this.mediaType = 'movie',
    this.initialSeason,
    this.mediaTitle = '',
  });

  final int? tmdbId;
  final String mediaType;
  final int? initialSeason;
  final String mediaTitle;

  final RxString searchKeyword = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<PansouItem> items = <PansouItem>[].obs;
  final RxString selectedFilter = 'all'.obs;
  final RxMap<String, bool> isTransferring = <String, bool>{}.obs;
  final RxMap<String, bool> transferredMap = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _initKeyword();
    fetchResults();
  }

  void _initKeyword() {
    final title = mediaTitle.trim();
    if (title.isNotEmpty) {
      if (mediaType != 'movie' && initialSeason != null && initialSeason! > 0) {
        searchKeyword.value = '$title 第$initialSeason季';
      } else {
        searchKeyword.value = title;
      }
    }
  }

  void updateKeyword(String newKeyword) {
    searchKeyword.value = newKeyword.trim();
    fetchResults();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  List<PansouItem> get filteredItems {
    switch (selectedFilter.value) {
      case '115':
        return items.where((e) => e.is115).toList();
      case 'magnet':
        return items.where((e) => e.isOfflineDownload).toList();
      case '4k':
        return items.where((e) => e.resolution == '4K').toList();
      default:
        return items.toList();
    }
  }

  int get count115 => items.where((e) => e.is115).length;
  int get countMagnet => items.where((e) => e.isOfflineDownload).length;
  int get count4k => items.where((e) => e.resolution == '4K').length;

  Future<void> fetchResults({bool refresh = false}) async {
    final kw = searchKeyword.value.trim();
    if (kw.isEmpty) {
      items.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final results = await PansouService.to.search(
        keyword: kw,
        refresh: refresh,
      );
      items.assignAll(results);
      if (results.isEmpty) {
        errorMessage.value = '未找到与「$kw」相关的 115 / 磁力资源';
      }
    } catch (e) {
      errorMessage.value = '搜索失败，请检查 PanSou 服务地址是否可用';
    } finally {
      isLoading.value = false;
    }
  }

  /// 发起 115 转存（支持分享转存与磁力/电驴离线）
  Future<void> transferToPan115({
    required BuildContext context,
    required PansouItem item,
  }) async {
    if (isTransferring[item.uniqueId] == true) return;

    // 适配现有的 Dian115TransferConfirmSheet 选择目标保存目录
    final dummyItem = Dian115ShareItem(
      id: item.uniqueId.hashCode,
      fileName: item.title,
      shareKind: item.is115 ? '115' : 'offline',
      shareUrl: item.is115 ? item.url : '',
      receiveCode: item.password,
      magnetUrl: item.isOfflineDownload ? item.url : '',
      resolution: item.resolution,
      season: item.season,
    );

    final selection = await Dian115TransferConfirmSheet.show(
      context,
      item: dummyItem,
      mediaType: mediaType,
      mediaTitle: mediaTitle.isNotEmpty ? mediaTitle : item.title,
      userPoints: 9999,
      isUnlock: false,
    );
    if (selection == null) return;

    isTransferring[item.uniqueId] = true;

    try {
      final result = await Pan115Service.to.transfer(
        mediaType: mediaType,
        shareUrl: item.is115 ? item.url : null,
        receiveCode: item.is115 ? item.password : null,
        magnetUrl: item.isOfflineDownload ? item.url : null,
        customCid: selection.cid,
        customFolderName: selection.folderName,
        item: dummyItem,
      );

      final isSuccess = result['success'] == true;
      final msg = result['msg']?.toString() ?? (isSuccess ? '已成功添加转存' : '转存失败');

      if (isSuccess) {
        transferredMap[item.uniqueId] = true;
        ToastUtil.success('转存成功: $msg');
      } else {
        ToastUtil.error('转存失败: $msg');
      }
    } catch (e) {
      ToastUtil.error('转存异常: $e');
    } finally {
      isTransferring[item.uniqueId] = false;
    }
  }
}
