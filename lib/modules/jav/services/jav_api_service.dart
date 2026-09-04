import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/services/app_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JavApiService {
  static final JavApiService _instance = JavApiService._internal();
  factory JavApiService() => _instance;

  static const String defaultBaseUrl = 'http://192.168.50.81:8923';
  late final Dio _dio;
  String _baseUrl = defaultBaseUrl;

  JavApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OmniHub-Mobile/1.2.3',
        },
      ),
    );
    _initBaseUrlSync();
  }

  void _initBaseUrlSync() {
    try {
      if (Get.isRegistered<AppService>()) {
        final appService = Get.find<AppService>();
        final server = appService.baseUrl;
        if (server != null && server.isNotEmpty) {
          final uri = Uri.tryParse(server);
          if (uri != null && uri.host.isNotEmpty) {
            final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
            updateBaseUrl('$scheme://${uri.host}:8923');
          }
        }
      }
    } catch (_) {}
  }

  Future<void> initBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('jav_server_url');
      if (saved != null && saved.trim().isNotEmpty) {
        updateBaseUrl(saved.trim());
        return;
      }
    } catch (_) {}
    _initBaseUrlSync();
  }

  Future<void> saveBaseUrl(String newUrl) async {
    updateBaseUrl(newUrl);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jav_server_url', _baseUrl);
    } catch (_) {}
  }

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    var url = newUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isNotEmpty) {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      _baseUrl = url;
      _dio.options.baseUrl = _baseUrl;
    }
  }

  /// 获取探索流作品 (带分页与分类)
  Future<List<JavItem>> fetchExplore({
    int page = 1,
    String? type,
    String? magnetType,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (magnetType != null && magnetType.isNotEmpty) {
        queryParams['magnet'] = magnetType;
      }

      final res = await _dio.get(
        '/api/jav/explore',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
      if (res.statusCode == 200 && res.data != null) {
        var data = res.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        List rawList = [];
        if (data is Map) {
          if (data['results'] is List) {
            rawList = data['results'] as List;
          } else if (data['data'] is List) {
            rawList = data['data'] as List;
          }
        } else if (data is List) {
          rawList = data;
        }

        return rawList
            .whereType<Map>()
            .map((e) => JavItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return [];
      }
      debugPrint('JavApiService.fetchExplore error: $e');
      rethrow;
    }
  }

  /// 获取番号完整详情 (包含 12 张样张、磁链等)
  Future<JavDetail?> fetchDetail(String code, {CancelToken? cancelToken}) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final res = await _dio.get(
        '/api/jav/detail/$cleanCode',
        cancelToken: cancelToken,
      );
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null && data is Map) {
        return JavDetail.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return null;
      }
      debugPrint('JavApiService.fetchDetail error for $code: $e');
      rethrow;
    }
  }

  /// 获取热门女优列表
  Future<List<JavActress>> fetchActresses({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get('/api/jav/actresses', cancelToken: cancelToken);
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null) {
        List rawList = [];
        if (data is Map && data['actresses'] is List) {
          rawList = data['actresses'] as List;
        } else if (data is List) {
          rawList = data;
        }

        return rawList
            .whereType<Map>()
            .map((e) => JavActress.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return [];
      }
      debugPrint('JavApiService.fetchActresses error: $e');
      return [];
    }
  }

  /// 获取 AI 推荐题材/找片标签
  Future<List<JavTagPrompt>> fetchTags({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get('/api/jav/tags', cancelToken: cancelToken);
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null) {
        List rawList = [];
        if (data is Map && data['tags'] is List) {
          rawList = data['tags'] as List;
        } else if (data is List) {
          rawList = data;
        }
        return rawList
            .whereType<Map>()
            .map((e) => JavTagPrompt.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return [];
      }
      debugPrint('JavApiService.fetchTags error: $e');
      return [];
    }
  }

  /// 搜索番号、演员或 AI 描述找片
  Future<JavSearchResult> search(
    String keyword, {
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/jav/search',
        queryParameters: {'query': keyword.trim(), 'page': page},
        cancelToken: cancelToken,
      );
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null) {
        List rawList = [];
        String? aiComment;
        String prompt = keyword;
        if (data is Map) {
          if (data['results'] is List) {
            rawList = data['results'] as List;
          }
          if (data['ai_comment'] is String) {
            aiComment = data['ai_comment'] as String;
          }
          if (data['prompt'] is String) {
            prompt = data['prompt'] as String;
          }
        } else if (data is List) {
          rawList = data;
        }
        final items = rawList
            .whereType<Map>()
            .map((e) => JavItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return JavSearchResult(
          prompt: prompt,
          aiComment: aiComment,
          results: items,
        );
      }
      return JavSearchResult(prompt: keyword, results: []);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return JavSearchResult(prompt: keyword, results: []);
      }
      debugPrint('JavApiService.search error: $e');
      rethrow;
    }
  }

  /// 构建防盗链代理图片 URL
  String getProxyImageUrl(String rawUrl, {String? code}) {
    if (rawUrl.isEmpty) return '';
    if (rawUrl.startsWith(_baseUrl)) return rawUrl;
    final encoded = Uri.encodeComponent(rawUrl);
    var target = '$_baseUrl/api/img/proxy?url=$encoded';
    if (code != null && code.isNotEmpty) {
      target += '&code=$code';
    }
    return target;
  }
}
