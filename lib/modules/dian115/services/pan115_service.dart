import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pan115Service extends GetxService {
  static Pan115Service get to {
    if (!Get.isRegistered<Pan115Service>()) {
      return Get.put(Pan115Service(), permanent: true);
    }
    return Get.find<Pan115Service>();
  }

  static const String defaultCookie =
      'UID=17987361_I1_1788850088; CID=365f183bb2a51d857c9e7f4c4b73d12c; SEID=cec8916b37ca6aa68d2c9761af6b363a42af99ee6e26e05de75b24921b825d36ff82a6c4fd35d3006d6942220c5cb31d69eef522ec4f9990fd7c017c; KID=a36b541eebcf01a9a4ca1406eee18f25';
  static const String defaultMovieCid = '3374319270869599334';
  static const String defaultTvCid = '3374342216908539463';

  static const String _prefCookieKey = 'pan115_user_cookie';
  static const String _prefMovieCidKey = 'pan115_movie_cid';
  static const String _prefTvCidKey = 'pan115_tv_cid';

  final RxString cookie = defaultCookie.obs;
  final RxString movieCid = defaultMovieCid.obs;
  final RxString tvCid = defaultTvCid.obs;

  late final Dio _dio;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OmnihubMobile/1.0',
        },
      ),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCookie = prefs.getString(_prefCookieKey);
      if (savedCookie != null && savedCookie.trim().isNotEmpty) {
        cookie.value = savedCookie.trim();
      }

      final savedMovieCid = prefs.getString(_prefMovieCidKey);
      if (savedMovieCid != null && savedMovieCid.trim().isNotEmpty) {
        movieCid.value = savedMovieCid.trim();
      }

      final savedTvCid = prefs.getString(_prefTvCidKey);
      if (savedTvCid != null && savedTvCid.trim().isNotEmpty) {
        tvCid.value = savedTvCid.trim();
      }
    } catch (e) {
      debugPrint('加载 115 配置异常: $e');
    }
  }

  Future<void> updateConfig({
    String? newCookie,
    String? newMovieCid,
    String? newTvCid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newCookie != null && newCookie.trim().isNotEmpty) {
        cookie.value = newCookie.trim();
        await prefs.setString(_prefCookieKey, newCookie.trim());
      }
      if (newMovieCid != null && newMovieCid.trim().isNotEmpty) {
        movieCid.value = newMovieCid.trim();
        await prefs.setString(_prefMovieCidKey, newMovieCid.trim());
      }
      if (newTvCid != null && newTvCid.trim().isNotEmpty) {
        tvCid.value = newTvCid.trim();
        await prefs.setString(_prefTvCidKey, newTvCid.trim());
      }
    } catch (e) {
      debugPrint('保存 115 配置异常: $e');
    }
  }

  static bool isMovieType({String? mediaType, Dian115ShareItem? item}) {
    // 若片源明确包含分季或集数，则确认为剧集
    if (item != null) {
      if (item.season > 0) return false;
      final s = item.seasons.trim();
      if (s.isNotEmpty && s != '0') return false;
      if (item.episodeCount > 0) return false;
    }

    if (mediaType == null || mediaType.isEmpty) {
      return true;
    }

    final lower = mediaType.toLowerCase();
    if (lower.contains('movie') || lower.contains('电影')) {
      return true;
    }
    if (lower.contains('tv') ||
        lower.contains('剧') ||
        lower.contains('show') ||
        lower.contains('series') ||
        lower.contains('anime')) {
      return false;
    }

    return true;
  }

  String getTargetCid(String mediaType, [Dian115ShareItem? item]) {
    if (isMovieType(mediaType: mediaType, item: item)) {
      return movieCid.value.isNotEmpty ? movieCid.value : defaultMovieCid;
    }
    return tvCid.value.isNotEmpty ? tvCid.value : defaultTvCid;
  }

  String getTargetFolderName(String mediaType, [Dian115ShareItem? item]) {
    if (isMovieType(mediaType: mediaType, item: item)) {
      return '电影目录';
    }
    return '电视剧目录';
  }

  /// 发起 115 转存操作
  Future<Map<String, dynamic>> transfer({
    required String mediaType,
    String? shareUrl,
    String? receiveCode,
    String? magnetUrl,
    List<String>? magnetUrls,
    String? customCid,
    String? customFolderName,
    Dian115ShareItem? item,
  }) async {
    final effectiveCid = customCid ?? getTargetCid(mediaType, item);
    final targetFolder = customFolderName ??
        (effectiveCid == (movieCid.value.isNotEmpty ? movieCid.value : defaultMovieCid)
            ? '电影目录'
            : (effectiveCid == (tvCid.value.isNotEmpty ? tvCid.value : defaultTvCid)
                ? '电视剧目录'
                : getTargetFolderName(mediaType, item)));

    // 汇总收集所有有效的离线下载链接 (支持 ed2k、magnet 等多链接批量)
    final effectiveOfflineUrls = <String>[];
    final seen = <String>{};
    void addOffline(String? u) {
      if (u == null) return;
      final trimmed = u.trim();
      if (trimmed.isEmpty) return;
      if (trimmed.contains('ed2k://') || trimmed.contains('magnet:?')) {
        final matches = RegExp(r'(ed2k://[^\s\r\n]+|magnet:\?[^\s\r\n]+)').allMatches(trimmed);
        if (matches.isNotEmpty) {
          for (final m in matches) {
            final link = m.group(0)?.trim() ?? '';
            if (link.isNotEmpty && seen.add(link)) {
              effectiveOfflineUrls.add(link);
            }
          }
          return;
        }
      }
      if (seen.add(trimmed)) {
        effectiveOfflineUrls.add(trimmed);
      }
    }

    if (magnetUrls != null) {
      for (final u in magnetUrls) {
        addOffline(u);
      }
    }
    addOffline(magnetUrl);
    if (item != null && item.urls.isNotEmpty) {
      for (final u in item.urls) {
        addOffline(u);
      }
    }

    final dianService = Dian115Service.to;
    final gatewayUrl = '${dianService.host.value}/api/pan115/transfer';

    final body = <String, dynamic>{
      'media_type': mediaType,
      'cid': effectiveCid,
      'cookie': cookie.value,
      if (shareUrl != null && shareUrl.isNotEmpty) 'share_url': shareUrl,
      if (receiveCode != null && receiveCode.isNotEmpty) 'receive_code': receiveCode,
      if (effectiveOfflineUrls.isNotEmpty) ...{
        'magnet_url': effectiveOfflineUrls.first,
        'magnet_urls': effectiveOfflineUrls,
      } else if (magnetUrl != null && magnetUrl.isNotEmpty) ...{
        'magnet_url': magnetUrl,
      },
    };

    try {
      final resp = await _dio.post(
        gatewayUrl,
        data: body,
        options: Options(contentType: 'application/json'),
      );

      if (resp.data is Map<String, dynamic>) {
        final data = resp.data as Map<String, dynamic>;
        return {
          'success': data['state'] == true || data['success'] == true,
          'target_folder': targetFolder,
          'cid': effectiveCid,
          'total_count': data['total_count'],
          'success_count': data['success_count'],
          'msg': data['msg'] ?? data['message'] ?? '转存完成',
          'raw': data,
        };
      }
    } catch (e) {
      debugPrint('网关转存失败，进行客户端直连兜底: $e');
    }

    // 客户端直连兜底方案
    return _transferDirect(
      mediaType: mediaType,
      effectiveCid: effectiveCid,
      targetFolder: targetFolder,
      shareUrl: shareUrl,
      receiveCode: receiveCode,
      effectiveOfflineUrls: effectiveOfflineUrls,
      singleMagnetUrl: magnetUrl,
    );
  }

  Future<Map<String, dynamic>> _transferDirect({
    required String mediaType,
    required String effectiveCid,
    required String targetFolder,
    String? shareUrl,
    String? receiveCode,
    List<String> effectiveOfflineUrls = const [],
    String? singleMagnetUrl,
  }) async {
    final directDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Cookie': cookie.value,
          'Referer': 'https://115.com/',
          'Origin': 'https://115.com',
          'Accept': 'application/json, text/javascript, */*',
        },
      ),
    );

    // 1. 离线磁力/电驴批量下载
    final targetUrls = effectiveOfflineUrls.isNotEmpty
        ? effectiveOfflineUrls
        : (singleMagnetUrl != null && singleMagnetUrl.trim().isNotEmpty
            ? [singleMagnetUrl.trim()]
            : <String>[]);

    if (targetUrls.isNotEmpty) {
      var successCount = 0;
      var duplicateCount = 0;
      final errorMsgs = <String>[];

      for (var i = 0; i < targetUrls.length; i++) {
        final currentUrl = targetUrls[i];
        try {
          final resp = await directDio.post(
            'https://115.com/web/lixian/?ct=lixian&ac=add_task_url',
            data: {
              'url': currentUrl,
              'wp_path_id': effectiveCid,
            },
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
            ),
          );
          final resData = resp.data is String ? jsonDecode(resp.data) : resp.data;
          final state = resData is Map ? resData['state'] == true : false;
          final errcode = resData is Map ? resData['errcode'] : null;

          if (state) {
            successCount++;
          } else if (errcode == 10008) {
            duplicateCount++;
            successCount++;
          } else {
            errorMsgs.add(resData?['error_msg']?.toString() ?? '第${i + 1}个链接添加失败');
          }
        } catch (e) {
          errorMsgs.add('第${i + 1}个链接请求异常: $e');
        }

        if (i < targetUrls.length - 1) {
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }

      final total = targetUrls.length;
      final isAllSuccess = successCount == total;
      final hasAnySuccess = successCount > 0;

      String msg;
      if (total == 1) {
        msg = isAllSuccess
            ? (duplicateCount > 0
                ? '该离线任务已在 $targetFolder 下载列表中'
                : '离线任务已成功添加至 $targetFolder')
            : (errorMsgs.isNotEmpty ? errorMsgs.first : '离线添加失败');
      } else {
        if (isAllSuccess) {
          msg = '已成功将全部 $total 个离线链接添加至 $targetFolder';
        } else if (hasAnySuccess) {
          msg = '部分完成：已成功添加 $successCount/$total 个任务至 $targetFolder';
        } else {
          msg = '全部离线任务添加失败 (${errorMsgs.take(2).join(", ")})';
        }
      }

      return {
        'success': hasAnySuccess,
        'target_folder': targetFolder,
        'cid': effectiveCid,
        'total_count': total,
        'success_count': successCount,
        'msg': msg,
      };
    }

    // 2. 115 分享链接转存
    if (shareUrl != null && shareUrl.trim().isNotEmpty) {
      final m = RegExp(r'/s/([a-zA-Z0-9]+)').firstMatch(shareUrl);
      final shareCode = m != null ? m.group(1)! : shareUrl.trim();
      final code = receiveCode?.trim() ?? '';

      try {
        final snapResp = await directDio.get(
          'https://webapi.115.com/share/snap',
          queryParameters: {
            'share_code': shareCode,
            'receive_code': code,
          },
        );
        final snapData = snapResp.data is String ? jsonDecode(snapResp.data) : snapResp.data;
        var fileIds = '';
        if (snapData is Map && snapData['data'] is Map && snapData['data']['list'] is List) {
          final list = snapData['data']['list'] as List;
          fileIds = list.map((e) => e['file_id']?.toString() ?? '').where((id) => id.isNotEmpty).join(',');
        }

        final recResp = await directDio.post(
          'https://webapi.115.com/share/receive',
          data: {
            'share_code': shareCode,
            'receive_code': code,
            'file_id': fileIds,
            'cid': effectiveCid,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {
              'Referer': 'https://115.com/s/$shareCode?password=$code',
            },
          ),
        );

        final recData = recResp.data is String ? jsonDecode(recResp.data) : recResp.data;
        final state = recData is Map ? recData['state'] == true : false;
        return {
          'success': state,
          'target_folder': targetFolder,
          'cid': effectiveCid,
          'msg': state ? '成功转存至 115 $targetFolder' : (recData?['error_msg'] ?? recData?['msg'] ?? '转存失败'),
          'raw': recData,
        };
      } catch (e) {
        return {
          'success': false,
          'target_folder': targetFolder,
          'cid': effectiveCid,
          'msg': '转存请求异常: $e',
        };
      }
    }

    return {
      'success': false,
      'target_folder': targetFolder,
      'cid': effectiveCid,
      'msg': '未提供有效的 115 链接或磁力链接',
    };
  }
}
