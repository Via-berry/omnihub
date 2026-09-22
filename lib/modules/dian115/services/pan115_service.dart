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

  /// 默认 115 Cookie 通过在构建期注入，不写入仓库：
  ///   flutter build ... --dart-define=PAN115_COOKIE="UID=...; CID=...; SEID=...; KID=..."
  /// 未注入时为空字符串，用户可在「癫影 115」设置面板中填写自己的 Cookie
  /// （见 dian115_share_sheet.dart 的 updateConfig 入口），并持久化到本机。
  ///
  /// 注意：dart-define 的值会被编译进产物，可被逆向提取。
  /// 如需真正的秘密，请勿使用共享 Cookie，改用服务端代理。
  static const String defaultCookie = String.fromEnvironment(
    'PAN115_COOKIE',
    defaultValue: '',
  );
  static const String defaultMovieCid = '3374319270869599334';
  static const String defaultTvCid = '3374342216908539463';

  static const String _prefCookieKey = 'pan115_user_cookie';
  static const String _prefMovieCidKey = 'pan115_movie_cid';
  static const String _prefTvCidKey = 'pan115_tv_cid';

  final RxString cookie = defaultCookie.obs;
  final RxString movieCid = defaultMovieCid.obs;
  final RxString tvCid = defaultTvCid.obs;
  final RxBool isCustomCookie = false.obs;

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
        isCustomCookie.value = true;
      } else {
        cookie.value = defaultCookie;
        isCustomCookie.value = false;
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
    bool resetCookieToDefault = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (resetCookieToDefault) {
        cookie.value = defaultCookie;
        isCustomCookie.value = false;
        await prefs.remove(_prefCookieKey);
      } else if (newCookie != null) {
        final trimmed = newCookie.trim();
        if (trimmed.isNotEmpty) {
          cookie.value = trimmed;
          isCustomCookie.value = true;
          await prefs.setString(_prefCookieKey, trimmed);
        }
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

  bool get hasConfiguredCookie => cookie.value.trim().isNotEmpty;
  bool get hasDefaultCookie => defaultCookie.trim().isNotEmpty;

  String get cookieSummary {
    final raw = cookie.value.trim();
    if (raw.isEmpty) return '未配置';
    final isCustom = isCustomCookie.value;
    final source = isCustom ? '自定义' : '内置注入';

    // 尝试提取 UID 简要显示
    final match = RegExp(r'UID=([^;]+)', caseSensitive: false).firstMatch(raw);
    if (match != null) {
      final uid = match.group(1)?.trim() ?? '';
      final maskedUid = uid.length > 5 ? '${uid.substring(0, 3)}***' : uid;
      return '$source (UID: $maskedUid)';
    }
    return '$source (已配置)';
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

    if (!hasConfiguredCookie) {
      return {
        'success': false,
        'target_folder': targetFolder,
        'cid': effectiveCid,
        'msg': '尚未配置 115 网盘凭证，请先在弹窗中配置您的 115 Cookie',
        'need_cookie': true,
      };
    }

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
        final isSuccess = data['state'] == true || data['success'] == true;
        if (isSuccess) {
          return {
            'success': true,
            'target_folder': targetFolder,
            'cid': effectiveCid,
            'total_count': data['total_count'],
            'success_count': data['success_count'],
            'msg': data['msg'] ?? data['message'] ?? '转存完成',
            'raw': data,
          };
        }

        // 网关返回失败时，深入解析 115 错误码
        final raw = data['raw'] is Map ? data['raw'] as Map : null;
        final errno = raw?['errno'] ?? data['errno'];
        final rawErr = raw?['error'] ?? raw?['error_msg'] ?? data['msg'] ?? data['message'];
        var errorMsg = rawErr?.toString() ?? '转存失败';
        if (errno == 990002 ||
            errno == 4100026 ||
            errno == 911 ||
            errorMsg.contains('未登录') ||
            errorMsg.contains('验证账号') ||
            errorMsg.contains('登录已超时')) {
          errorMsg = '115 网盘凭证已失效（登录过期），请在转存弹窗中更新 115 Cookie';
        }

        // 若不是 Cookie 失效导致的网关失败，尝试客户端直连兜底
        if (errno != 990002 && errno != 4100026 && errno != 911) {
          debugPrint('网关响应失败，尝试客户端直连兜底: $errorMsg');
          final directRes = await _transferDirect(
            mediaType: mediaType,
            effectiveCid: effectiveCid,
            targetFolder: targetFolder,
            shareUrl: shareUrl,
            receiveCode: receiveCode,
            effectiveOfflineUrls: effectiveOfflineUrls,
            singleMagnetUrl: magnetUrl,
          );
          if (directRes['success'] == true) {
            return directRes;
          }
        }

        return {
          'success': false,
          'target_folder': targetFolder,
          'cid': effectiveCid,
          'msg': errorMsg,
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
          final errno = resData is Map ? resData['errno'] : null;

          if (state) {
            successCount++;
          } else if (errcode == 10008) {
            duplicateCount++;
            successCount++;
          } else if (errno == 911 || errno == 990002) {
            errorMsgs.add('115 账号凭证失效，请更新 Cookie');
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
        if (snapData is Map && snapData['state'] != true) {
          final snapErrno = snapData['errno'];
          final snapMsg = snapData['error'] ?? snapData['error_msg'] ?? snapData['msg'] ?? '获取分享快照失败';
          var friendlyMsg = '115 分享快照获取失败: $snapMsg';
          if (snapErrno == 990002 || snapErrno == 911 || snapMsg.toString().contains('登录')) {
            friendlyMsg = '115 网盘凭证已失效（登录过期），请在转存弹窗中更新 115 Cookie';
          }
          return {
            'success': false,
            'target_folder': targetFolder,
            'cid': effectiveCid,
            'msg': friendlyMsg,
            'raw': snapData,
          };
        }

        var fileIds = '';
        if (snapData is Map && snapData['data'] is Map && snapData['data']['list'] is List) {
          final list = snapData['data']['list'] as List;
          fileIds = list
              .map((e) => (e['file_id'] ?? e['fid'] ?? e['cid'])?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .join(',');
        }

        if (fileIds.isEmpty) {
          return {
            'success': false,
            'target_folder': targetFolder,
            'cid': effectiveCid,
            'msg': '未能从该 115 分享中提取出有效文件 ID',
            'raw': snapData,
          };
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
        final recErrno = recData is Map ? recData['errno'] : null;
        var recMsg = recData?['error_msg'] ?? recData?['msg'] ?? (state ? '成功转存至 115 $targetFolder' : '转存失败');
        if (recErrno == 990002 || recErrno == 911 || recMsg.toString().contains('登录')) {
          recMsg = '115 网盘凭证已失效（登录过期），请在转存弹窗中更新 115 Cookie';
        }

        return {
          'success': state,
          'target_folder': targetFolder,
          'cid': effectiveCid,
          'msg': recMsg,
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
