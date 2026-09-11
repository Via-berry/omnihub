import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dian115Service extends GetxService {
  static Dian115Service get to {
    if (!Get.isRegistered<Dian115Service>()) {
      return Get.put(Dian115Service(), permanent: true);
    }
    return Get.find<Dian115Service>();
  }

  static const String defaultHost = 'http://192.168.50.81:8924';
  static const String _hostPrefKey = 'dian115_server_host';
  static const String _unlockedMapKey = 'dian115_unlocked_items_map';

  final RxString host = defaultHost.obs;
  final RxMap<int, Dian115UnlockResult> unlockedMap = <int, Dian115UnlockResult>{}.obs;
  final Rx<Dian115StatusResult?> accountStatus = Rx<Dian115StatusResult?>(null);
  final RxString lastSyncError = ''.obs;

  bool get isLanHost {
    final h = host.value.toLowerCase();
    return h.contains('192.168.') ||
        h.contains('10.') ||
        h.contains('172.16.') ||
        h.contains('172.17.') ||
        h.contains('172.18.') ||
        h.contains('172.19.') ||
        h.contains('172.2') ||
        h.contains('172.3') ||
        h.contains('localhost') ||
        h.contains('127.0.0.1');
  }

  late final Dio _dio;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OmnihubMobile/1.0',
        },
      ),
    );
    _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString(_hostPrefKey);
      if (savedHost != null && savedHost.trim().isNotEmpty) {
        host.value = savedHost.trim();
      }

      final rawUnlocked = prefs.getString(_unlockedMapKey);
      if (rawUnlocked != null && rawUnlocked.isNotEmpty) {
        final decoded = jsonDecode(rawUnlocked) as Map<String, dynamic>?;
        if (decoded != null) {
          final mapped = <int, Dian115UnlockResult>{};
          decoded.forEach((key, value) {
            final id = int.tryParse(key);
            if (id != null && value is Map<String, dynamic>) {
              mapped[id] = Dian115UnlockResult.fromJson(value);
            }
          });
          unlockedMap.assignAll(mapped);
        }
      }
    } catch (_) {}
  }

  Future<void> updateHost(String newHost) async {
    var cleaned = newHost.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    host.value = cleaned;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hostPrefKey, cleaned);
    } catch (_) {}
  }

  String _cleanUrl(String path) {
    var currentHost = host.value.trim();
    if (currentHost.endsWith('/')) {
      currentHost = currentHost.substring(0, currentHost.length - 1);
    }
    return '$currentHost$path';
  }

  bool isUnlocked(int shareId) => unlockedMap.containsKey(shareId);

  Dian115UnlockResult? getUnlockedInfo(int shareId) => unlockedMap[shareId];

  Future<void> saveUnlockedInfo(int shareId, Dian115UnlockResult result) async {
    unlockedMap[shareId] = result;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = <String, dynamic>{};
      unlockedMap.forEach((key, val) {
        mapToSave[key.toString()] = val.toJson();
      });
      await prefs.setString(_unlockedMapKey, jsonEncode(mapToSave));
    } catch (_) {}
  }

  /// 获取网关与账号状态
  Future<Dian115StatusResult> getStatus() async {
    try {
      final resp = await _dio.get(_cleanUrl('/api/status'));
      if (resp.data is Map<String, dynamic>) {
        final result = Dian115StatusResult.fromJson(resp.data as Map<String, dynamic>);
        accountStatus.value = result;
        return result;
      }
      return const Dian115StatusResult(service: 'unknown');
    } catch (e) {
      accountStatus.value = const Dian115StatusResult(service: 'offline');
      rethrow;
    }
  }

  /// 查询特定 TMDB 的全量分享列表
  Future<Dian115SharesResponse> getShares({
    required int tmdbId,
    String mediaType = 'movie',
    int? season,
  }) async {
    final queryParams = <String, dynamic>{
      'tmdb_id': tmdbId,
      'media_type': mediaType.toLowerCase() == 'tv' ? 'tv' : 'movie',
    };
    if (season != null && season >= 0) {
      queryParams['season'] = season;
    }

    final resp = await _dio.get(
      _cleanUrl('/api/media/shares'),
      queryParameters: queryParams,
    );

    if (resp.data is Map<String, dynamic>) {
      final res = Dian115SharesResponse.fromJson(resp.data as Map<String, dynamic>);
      for (final s in res.shares) {
        if (s.isUnlocked && (s.shareUrl.isNotEmpty || s.magnetUrl.isNotEmpty)) {
          final cached = Dian115UnlockResult(
            code: 'ok',
            shareUrl: s.shareUrl,
            receiveCode: s.receiveCode,
            magnetUrl: s.magnetUrl,
            pointsCost: s.unlockCost,
          );
          unlockedMap[s.id] = cached;
        }
      }
      return res;
    }
    throw Exception('返回数据格式异常');
  }

  /// 影视关键词全局检索（用于无 TMDB ID 时的自动兜底匹配）
  Future<Dian115SearchResult> searchMedia(String keyword, {int page = 1}) async {
    final resp = await _dio.get(
      _cleanUrl('/api/search'),
      queryParameters: {
        'q': keyword.trim(),
        'page': page,
      },
    );

    if (resp.data is Map<String, dynamic>) {
      return Dian115SearchResult.fromJson(resp.data as Map<String, dynamic>);
    }
    throw Exception('检索返回数据异常');
  }

  /// 获取当前已登录会话的 Cookie，用于客户端原生 WebView 免登
  Future<Map<String, dynamic>> getAuthCookies() async {
    try {
      final resp = await _dio.get(_cleanUrl('/api/auth/cookies'));
      if (resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return const {};
  }

  /// 将客户端/移动端提取到的最新会话 Cookie 和用户数据同步给 NAS 网关
  Future<bool> importSession({
    required List<Map<String, dynamic>> cookies,
    Map<String, dynamic>? userData,
    String? cookieString,
  }) async {
    lastSyncError.value = '';
    try {
      final body = <String, dynamic>{
        'cookies': cookies,
        if (userData != null) 'user_data': userData,
        if (cookieString != null && cookieString.isNotEmpty)
          'cookie_string': cookieString,
      };

      final resp = await _dio.post(
        _cleanUrl('/api/auth/session'),
        data: body,
        options: Options(
          contentType: 'application/json',
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (resp.data is Map<String, dynamic>) {
        final data = resp.data as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        if (success) {
          await getStatus().catchError((_) => const Dian115StatusResult());
          return true;
        } else {
          lastSyncError.value = data['message'] as String? ?? '网关未能识别该会话';
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        if (isLanHost) {
          lastSyncError.value =
              '无法连接到 NAS 网关 (${host.value})。检测到当前网关为局域网 IP，若处于移动网络 (5G/4G)，请连接家庭 WiFi 或开启回家代理。';
        } else {
          lastSyncError.value = '无法连接到 NAS 网关 (${host.value})，连接超时或网络不可达';
        }
      } else {
        String? detailMsg;
        if (e.response?.data is Map<String, dynamic>) {
          final data = e.response!.data as Map<String, dynamic>;
          detailMsg = data['detail']?.toString() ?? data['message']?.toString();
        } else if (e.response?.data is String) {
          try {
            final data = jsonDecode(e.response!.data as String);
            if (data is Map<String, dynamic>) {
              detailMsg =
                  data['detail']?.toString() ?? data['message']?.toString();
            }
          } catch (_) {}
        }
        if (detailMsg != null && detailMsg.isNotEmpty) {
          lastSyncError.value =
              '网关请求失败 (${e.response?.statusCode ?? 400}): $detailMsg';
        } else {
          lastSyncError.value =
              '网关请求失败 (${e.response?.statusCode ?? e.message})';
        }
      }
      debugPrint('Dian115Service importSession DioException: $e');
    } catch (e) {
      lastSyncError.value = '同步异常: $e';
      debugPrint('Dian115Service importSession error: $e');
    }
    return false;
  }

  /// 资源解锁
  Future<Dian115UnlockResult> unlockShare(
    int shareId, {
    int? resourceId,
    String? turnstileToken,
    int? tmdbId,
    String? mediaType,
    int? season,
  }) async {
    final body = <String, dynamic>{
      'share_id': shareId,
      if (resourceId != null) 'resource_id': resourceId,
      if (turnstileToken != null && turnstileToken.isNotEmpty)
        'turnstile_token': turnstileToken,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (mediaType != null) 'media_type': mediaType,
      if (season != null) 'season': season,
    };

    final resp = await _dio.post(
      _cleanUrl('/api/shares/unlock'),
      data: body,
      options: Options(contentType: 'application/json'),
    );

    if (resp.data is Map<String, dynamic>) {
      final map = resp.data as Map<String, dynamic>;
      final result = Dian115UnlockResult.fromJson(map);
      if (result.isSuccess) {
        await saveUnlockedInfo(shareId, result);
        // 解锁后顺带刷新积分
        getStatus().catchError((_) => const Dian115StatusResult());
      }
      return result;
    }
    throw Exception('解锁响应异常');
  }

  /// 每日签到
  Future<Map<String, dynamic>> signin({String mode = 'normal'}) async {
    final resp = await _dio.post(
      _cleanUrl('/api/signin'),
      queryParameters: {'mode': mode},
    );

    if (resp.data is Map<String, dynamic>) {
      // 签到后刷新状态
      await getStatus();
      return resp.data as Map<String, dynamic>;
    }
    return {'code': 'ok'};
  }
}
