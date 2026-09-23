import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 115 凭证在线状态
enum One115CookieStatus { unknown, checking, online, offline }

/// 离线下载协议链接：磁力 / 电驴
final RegExp _offlineLinkPattern = RegExp(r'(ed2k://[^\s\r\n]+|magnet:\?[^\s\r\n]+)');

/// 可作为 115 离线下载的种子文件地址（http/https 直链，如 .torrent 文件）
bool isOfflineFileUrl(String url) {
  final lower = url.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// 网盘分享链接特征域名。
///
/// 这类链接必须走分享转存（share/snap + share/receive）。一旦被当作离线下载
/// 地址提交，115 会去"下载"这个 URL，把整个分享页存成一个 txt/html 文件。
const List<String> _panShareHostHints = [
  '115.com',
  '115cdn.com',
  'anxia.com',
  'quark.cn',
  'alipan.com',
  'aliyundrive.com',
  'baidu.com',
  'xunlei.com',
  'drive.uc.cn',
  '189.cn',
  '123pan.com',
];

bool looksLikePanShareUrl(String url) {
  final lower = url.toLowerCase();
  for (final host in _panShareHostHints) {
    if (lower.contains(host)) return true;
  }
  return false;
}

/// 校验磁力链接的 info-hash 是否完整。
///
/// 盘搜部分数据源会返回被截断的磁力（btih 只有三四十位而非完整的 40 位
/// 十六进制或 32 位 base32）。这类磁力在 115 侧无法匹配到真实资源，
/// 提交后只会得到一个内容为链接文本的垃圾 txt 文件，必须提交前拦下。
bool isValidMagnetLink(String magnet) {
  final xt = RegExp(r'[?&]xt=urn:(btih|btmh):([^&\s]+)').firstMatch(magnet);
  if (xt == null) return true; // 无 xt 的稀有格式交给 115 判定
  final kind = xt.group(1)!;
  final hash = xt.group(2)!;
  switch (kind) {
    case 'btih':
      // SHA-1：40 位十六进制，或 32 位 base32（RFC 4648 无填充）
      return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hash) ||
          RegExp(r'^[A-Z2-7]{32}$').hasMatch(hash);
    case 'btmh':
      // 多哈希：前缀 + 摘要，至少 8 位十六进制
      return RegExp(r'^[0-9a-fA-F]{8,}$').hasMatch(hash);
    default:
      return true;
  }
}

/// 离线下载链接收集结果
class OfflineUrlCollection {
  final List<String> validUrls;
  final List<String> invalidMagnets;
  final List<String> droppedTexts;
  final List<String> panShareUrls;

  const OfflineUrlCollection(
    this.validUrls,
    this.invalidMagnets,
    this.droppedTexts,
    this.panShareUrls,
  );

  bool get hasRejected =>
      panShareUrls.isNotEmpty ||
      invalidMagnets.isNotEmpty ||
      droppedTexts.isNotEmpty;

  String get rejectedNote {
    final parts = <String>[];
    if (panShareUrls.isNotEmpty) {
      parts.add('网盘分享链接 ${panShareUrls.length} 条');
    }
    if (invalidMagnets.isNotEmpty) {
      parts.add('磁力链接 info-hash 不完整 ${invalidMagnets.length} 条');
    }
    if (droppedTexts.isNotEmpty) {
      parts.add('非链接文本 ${droppedTexts.length} 条');
    }
    return parts.join('、');
  }
}

/// 从盘搜条目中收集可提交给 115 离线下载的链接。
///
/// 两类内容绝不能进这个列表，否则 115 会把它落成垃圾文件：
/// 1. 盘搜混在 urls 里的资源名、编号（如 "swsaoay36l0"）
/// 2. 网盘分享链接——它必须走分享转存，当作离线地址提交会让 115 把整个
///    分享页下载成一个 txt/html 文件，而不是转存分享里的资源
OfflineUrlCollection collectOfflineUrls(Iterable<String?> candidates) {
  final validUrls = <String>[];
  final invalidMagnets = <String>[];
  final droppedTexts = <String>[];
  final panShareUrls = <String>[];
  final seen = <String>{};

  for (final raw in candidates) {
    if (raw == null) continue;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.contains('magnet:?') || trimmed.contains('ed2k://')) {
      for (final m in _offlineLinkPattern.allMatches(trimmed)) {
        final link = (m.group(0) ?? '').trim();
        if (link.isEmpty || !seen.add(link)) continue;
        if (link.startsWith('magnet:?') && !isValidMagnetLink(link)) {
          invalidMagnets.add(link);
        } else {
          validUrls.add(link);
        }
      }
      continue;
    }

    if (isOfflineFileUrl(trimmed)) {
      if (looksLikePanShareUrl(trimmed)) {
        if (seen.add(trimmed)) panShareUrls.add(trimmed);
      } else if (seen.add(trimmed)) {
        validUrls.add(trimmed);
      }
      continue;
    }

    if (seen.add(trimmed)) droppedTexts.add(trimmed);
  }

  return OfflineUrlCollection(validUrls, invalidMagnets, droppedTexts, panShareUrls);
}

class Pan115Service extends GetxService {
  static Pan115Service get to {
    if (!Get.isRegistered<Pan115Service>()) {
      return Get.put(Pan115Service(), permanent: true);
    }
    return Get.find<Pan115Service>();
  }

  static const String defaultMovieCid = '3374319270869599334';
  static const String defaultTvCid = '3374342216908539463';

  static const String _prefCookieKey = 'pan115_user_cookie';
  static const String _prefMovieCidKey = 'pan115_movie_cid';
  static const String _prefTvCidKey = 'pan115_tv_cid';

  final RxString cookie = ''.obs;
  final RxString movieCid = defaultMovieCid.obs;
  final RxString tvCid = defaultTvCid.obs;
  final Rx<One115CookieStatus> cookieStatus = One115CookieStatus.unknown.obs;

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
      if (newCookie != null) {
        final trimmed = newCookie.trim();
        if (trimmed.isEmpty) {
          cookie.value = '';
          await prefs.remove(_prefCookieKey);
        } else {
          cookie.value = trimmed;
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

  /// 探测当前 Cookie 是否仍然有效（移植自 115scan one15-status.mjs）
  Future<void> refreshCookieStatus() async {
    final raw = cookie.value.trim();
    if (raw.isEmpty) {
      cookieStatus.value = One115CookieStatus.offline;
      return;
    }
    if (cookieStatus.value == One115CookieStatus.checking) return;
    cookieStatus.value = One115CookieStatus.checking;
    try {
      final probe = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Cookie': raw,
            'Accept': 'application/json, text/plain, */*',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        ),
      );
      try {
        final resp = await probe.get(
          'https://aps.115.com/natsort/files.php?aid=1&cid=0&offset=0&show_dir=1&limit=1&format=json',
        );
        final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
        if (data is Map && data['state'] == true) {
          cookieStatus.value = One115CookieStatus.online;
        } else {
          final text =
              '${data?['error'] ?? ''} ${data?['message'] ?? ''}';
          final expired = data?['errno'] == 99 ||
              text.contains('请先登录') ||
              text.contains('请重新登录');
          cookieStatus.value = expired
              ? One115CookieStatus.offline
              : One115CookieStatus.unknown;
        }
      } finally {
        probe.close();
      }
    } catch (e) {
      debugPrint('115 凭证探针异常: $e');
      cookieStatus.value = One115CookieStatus.unknown;
    }
  }

  /// 扫码登录成功后保存 Cookie（复用手动配置的持久化链路）
  Future<void> saveQrLoginCookie(String cookieString) async {
    await updateConfig(newCookie: cookieString);
    cookieStatus.value = One115CookieStatus.online;
  }

  void markCookieOffline() {
    cookieStatus.value = One115CookieStatus.offline;
  }

  String get cookieSummary {
    final raw = cookie.value.trim();
    if (raw.isEmpty) return '未配置';

    // 尝试提取 UID 简要显示
    final match = RegExp(r'UID=([^;]+)', caseSensitive: false).firstMatch(raw);
    if (match != null) {
      final uid = match.group(1)?.trim() ?? '';
      final maskedUid = uid.length > 5 ? '${uid.substring(0, 3)}***' : uid;
      return 'UID: $maskedUid';
    }
    return '已配置';
  }

  /// 弹窗回填用的脱敏 Cookie：保留键名，值只露前 2 位。
  /// 保存时若文本与此一致则视为未修改，避免把脱敏串写回覆盖真实 Cookie。
  static String maskCookie(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(';').map((pair) {
      final kv = pair.split('=');
      if (kv.length < 2) return pair.trim();
      final name = kv[0].trim();
      final value = kv.sublist(1).join('=').trim();
      if (value.isEmpty) return '$name=';
      final head = value.length <= 2 ? value : value.substring(0, 2);
      return '$name=$head***';
    }).join('; ');
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
    // 只从离线专用字段收集，不喂 item.urls：115 分享条目的 urls 装的是
    // 分享链接，一旦被当成离线地址提交，115 会把整个分享页下载成 txt 文件
    final collected = collectOfflineUrls([
      if (magnetUrls != null) ...magnetUrls,
      magnetUrl,
    ]);
    final effectiveOfflineUrls = collected.validUrls;

    // 没有任何可提交的离线链接时不要退化到把原始文本当 url 发出去
    if (effectiveOfflineUrls.isEmpty &&
        (shareUrl == null || shareUrl.trim().isEmpty)) {
      final note = collected.rejectedNote;
      return {
        'success': false,
        'target_folder': targetFolder,
        'cid': effectiveCid,
        'msg': note.isEmpty
            ? '未提供有效的 115 链接或磁力链接'
            : '未提交离线任务：$note（盘搜返回的数据不完整，请复制完整链接重试）',
      };
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
          markCookieOffline();
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
            rejectedNote: collected.rejectedNote,
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
      rejectedNote: collected.rejectedNote,
    );
  }

  Future<Map<String, dynamic>> _transferDirect({
    required String mediaType,
    required String effectiveCid,
    required String targetFolder,
    String? shareUrl,
    String? receiveCode,
    List<String> effectiveOfflineUrls = const [],
    String? rejectedNote,
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

    try {
      // 1. 离线磁力/电驴批量下载
    final targetUrls = effectiveOfflineUrls;

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
            markCookieOffline();
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

      // 让被拦下的链接可见，否则用户只看到"成功"却少了任务
      final rejectedSuffix = (rejectedNote != null && rejectedNote.isNotEmpty)
          ? '（另有 $rejectedNote 未提交，115 无法处理）'
          : '';

      return {
        'success': hasAnySuccess,
        'target_folder': targetFolder,
        'cid': effectiveCid,
        'total_count': total,
        'success_count': successCount,
        'msg': msg + rejectedSuffix,
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
            markCookieOffline();
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
          markCookieOffline();
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
    } finally {
      directDio.close();
    }
  }
}
