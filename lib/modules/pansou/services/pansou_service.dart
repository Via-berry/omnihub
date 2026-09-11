import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/pansou/models/pansou_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PansouService extends GetxService {
  static PansouService get to {
    if (!Get.isRegistered<PansouService>()) {
      return Get.put(PansouService(), permanent: true);
    }
    return Get.find<PansouService>();
  }

  static const String defaultHost = 'http://192.168.50.81:8888';
  static const String _hostPrefKey = 'pansou_server_host';
  static const String _tokenPrefKey = 'pansou_server_token';

  final RxString host = defaultHost.obs;
  final RxString token = ''.obs;

  late final Dio _dio;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 35),
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
      final savedToken = prefs.getString(_tokenPrefKey);
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        token.value = savedToken.trim();
      }
    } catch (e) {
      debugPrint('加载 PanSou 服务配置失败: $e');
    }
  }

  Future<void> updateConfig({String? newHost, String? newToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newHost != null && newHost.trim().isNotEmpty) {
        var cleaned = newHost.trim();
        if (cleaned.endsWith('/')) {
          cleaned = cleaned.substring(0, cleaned.length - 1);
        }
        host.value = cleaned;
        await prefs.setString(_hostPrefKey, cleaned);
      }
      if (newToken != null) {
        token.value = newToken.trim();
        await prefs.setString(_tokenPrefKey, newToken.trim());
      }
    } catch (e) {
      debugPrint('保存 PanSou 服务配置失败: $e');
    }
  }

  /// 发起 PanSou 资源搜索，默认筛选 115、磁力与电驴
  Future<List<PansouItem>> search({
    required String keyword,
    List<String> cloudTypes = const ['115', 'magnet', 'ed2k'],
    bool refresh = false,
  }) async {
    final cleanKw = keyword.trim();
    if (cleanKw.isEmpty) return [];

    final targetHost = host.value.isNotEmpty ? host.value : defaultHost;
    final url = '$targetHost/api/search';

    final queryParams = <String, dynamic>{
      'kw': cleanKw,
      'cloud_types': cloudTypes.join(','),
      'res': 'merge',
      if (refresh) 'refresh': 'true',
    };

    final headers = <String, dynamic>{
      if (token.value.isNotEmpty) 'Authorization': 'Bearer ${token.value}',
    };

    try {
      final response = await _dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      final rawData = response.data;
      Map<String, dynamic>? dataMap;
      if (rawData is Map<String, dynamic>) {
        dataMap = rawData;
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          dataMap = decoded;
        }
      }

      if (dataMap == null) return [];

      // 提取 data.merged_by_type
      final dataObj = dataMap['data'];
      if (dataObj is! Map<String, dynamic>) return [];

      final mergedByType = dataObj['merged_by_type'];
      if (mergedByType is! Map<String, dynamic>) return [];

      final results = <PansouItem>[];
      var index = 0;

      // 优先提取 115，然后 magnet，然后 ed2k
      final targetTypes = ['115', 'magnet', 'ed2k'];
      for (final typeKey in targetTypes) {
        final list = mergedByType[typeKey];
        if (list is List) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              results.add(
                PansouItem.fromMergedJson(
                  rawType: typeKey,
                  json: item,
                  index: index++,
                ),
              );
            }
          }
        }
      }

      // 其他网盘如果有也可以兼容提取（若有 115 以外符合预期的）
      mergedByType.forEach((key, value) {
        if (!targetTypes.contains(key) && value is List) {
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              results.add(
                PansouItem.fromMergedJson(
                  rawType: key,
                  json: item,
                  index: index++,
                ),
              );
            }
          }
        }
      });

      return results;
    } catch (e) {
      debugPrint('PanSou 搜索异常: $e');
      rethrow;
    }
  }

  /// 健康检查
  Future<bool> checkHealth() async {
    final targetHost = host.value.isNotEmpty ? host.value : defaultHost;
    final url = '$targetHost/api/health';
    try {
      final resp = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  final Map<String, Pansou115SnapInfo> _snapCache = {};

  /// 解析 115 分享链接真实容量与有效性
  Future<Pansou115SnapInfo?> fetch115ShareSnap(
    String shareUrl, {
    String? receiveCode,
  }) async {
    final cleanUrl = shareUrl.trim();
    if (cleanUrl.isEmpty) return null;

    final match = RegExp(r'/s/([a-zA-Z0-9]+)').firstMatch(cleanUrl);
    if (match == null) return null;
    final shareCode = match.group(1)!;

    var pwd = receiveCode?.trim() ?? '';
    if (pwd.isEmpty) {
      final uri = Uri.tryParse(cleanUrl);
      pwd = uri?.queryParameters['password'] ??
          uri?.queryParameters['pwd'] ??
          '';
    }

    final cacheKey = '${shareCode}_$pwd';
    if (_snapCache.containsKey(cacheKey)) {
      return _snapCache[cacheKey];
    }

    const snapUrl = 'https://webapi.115.com/share/snap';
    try {
      final resp = await _dio.get(
        snapUrl,
        queryParameters: {
          'share_code': shareCode,
          if (pwd.isNotEmpty) 'receive_code': pwd,
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/javascript, */*',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final rawData = resp.data;
      Map<String, dynamic>? dataMap;
      if (rawData is Map<String, dynamic>) {
        dataMap = rawData;
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          dataMap = decoded;
        }
      }

      if (dataMap == null) return null;

      final state = dataMap['state'] == true;
      if (!state) {
        final errorMsg = dataMap['error']?.toString() ?? '分享已失效';
        final invalidInfo = Pansou115SnapInfo(
          isValid: false,
          errorMessage: errorMsg,
        );
        _snapCache[cacheKey] = invalidInfo;
        return invalidInfo;
      }

      final dataObj = dataMap['data'];
      var fileSizeBytes = 0;
      var shareTitle = '';
      var fileCount = 0;

      if (dataObj is Map<String, dynamic>) {
        final shareInfo = dataObj['shareinfo'];
        if (shareInfo is Map<String, dynamic>) {
          fileSizeBytes = shareInfo['file_size'] as int? ??
              int.tryParse(shareInfo['file_size']?.toString() ?? '') ??
              0;
          shareTitle = shareInfo['share_title']?.toString() ?? '';
        }
        fileCount = dataObj['count'] as int? ??
            int.tryParse(dataObj['count']?.toString() ?? '') ??
            0;
      }

      final snapResult = Pansou115SnapInfo(
        isValid: true,
        fileSizeBytes: fileSizeBytes,
        fileSizeHuman: Pansou115SnapInfo.formatBytes(fileSizeBytes),
        fileCount: fileCount,
        shareTitle: shareTitle,
      );

      _snapCache[cacheKey] = snapResult;
      return snapResult;
    } catch (e) {
      debugPrint('获取 115 分享快照失败 ($shareCode): $e');
      return null;
    }
  }
}
