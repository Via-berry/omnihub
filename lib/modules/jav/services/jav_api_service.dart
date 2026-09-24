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
          'User-Agent': 'OmniHub-Mobile/1.2.7',
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
    int limit = 30,
    String? type,
    String? magnetType,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
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

  /// 获取 JAV 模块系统与安全配置 (如允许放行 host、MissAV 主站域名等)
  Future<JavSettings?> fetchSettings({CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get('/api/jav/settings', cancelToken: cancelToken);
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null && data is Map) {
        return JavSettings.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return null;
      }
      debugPrint('JavApiService.fetchSettings error: $e');
      return null;
    }
  }

  /// 获取 MissAV 首页推荐与分段题材推荐
  Future<JavHomeRecommendations?> fetchMissavHome({
    int count = 12,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/jav/missav/home',
        queryParameters: {'count': count},
        cancelToken: cancelToken,
      );
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null && data is Map) {
        return JavHomeRecommendations.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return null;
      }
      debugPrint('JavApiService.fetchMissavHome error: $e');
      return null;
    }
  }

  /// 获取番号完整详情 (支持 MissAV 主数据源与 JavBus 回退)
  Future<JavDetail?> fetchDetail(
    String code, {
    String? source,
    String? locale,
    CancelToken? cancelToken,
  }) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final queryParams = <String, dynamic>{};
      if (source != null && source.isNotEmpty) {
        queryParams['source'] = source;
      }
      if (locale != null && locale.isNotEmpty) {
        queryParams['locale'] = locale;
      }
      final res = await _dio.get(
        '/api/jav/detail/$cleanCode',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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

  /// 换取最新流媒体 HLS 直链
  Future<JavStreams?> fetchStreams(String code, {CancelToken? cancelToken}) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final res = await _dio.get(
        '/api/jav/streams/$cleanCode',
        cancelToken: cancelToken,
      );
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null && data is Map) {
        if (data['streams'] is Map) {
          return JavStreams.fromJson(Map<String, dynamic>.from(data['streams'] as Map));
        }
      }
      return null;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return null;
      }
      debugPrint('JavApiService.fetchStreams error for $code: $e');
      return null;
    }
  }


  /// 获取女优列表 (支持分页与每页数量)
  Future<List<JavActress>> fetchActresses({
    int page = 1,
    int limit = 30,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/jav/actresses',
        queryParameters: {'page': page, 'limit': limit},
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

  /// 按分类与题材拉取影片流（有码 censored、无码 uncensored、人气 popular、中字 subtitled）
  Future<List<JavItem>> fetchCategoryExplore({
    String category = 'censored',
    String genre = '',
    int page = 1,
    int limit = 30,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/jav/explore',
        queryParameters: {
          'category': category,
          'genre': genre,
          'page': page,
          'limit': limit,
        },
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
        if (data is Map && data['results'] is List) {
          rawList = data['results'] as List;
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
      debugPrint('JavApiService.fetchCategoryExplore error: $e');
      rethrow;
    }
  }

  /// 获取母库分类题材标签列表 (默认使用 MissAV 自建题材索引)
  Future<List<JavGenre>> fetchGenres({
    String category = 'censored',
    String? source,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{'category': category};
      if (source != null && source.isNotEmpty) {
        queryParams['source'] = source;
      }
      final res = await _dio.get(
        '/api/jav/genres',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
      var data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (res.statusCode == 200 && data != null && data is Map) {
        if (data['genres'] is List) {
          return (data['genres'] as List)
              .whereType<Map>()
              .map((e) => JavGenre.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return [];
      }
      debugPrint('JavApiService.fetchGenres error: $e');
      return [];
    }
  }

  /// 搜索番号、演员或 AI 描述找片
  Future<JavSearchResult> search(
    String keyword, {
    String category = 'all',
    int page = 1,
    int limit = 30,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/jav/search',
        queryParameters: {
          'query': keyword.trim(),
          'category': category,
          'page': page,
          'limit': limit,
        },
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
