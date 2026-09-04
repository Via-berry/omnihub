import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';

class JavApiService {
  static final JavApiService _instance = JavApiService._internal();
  factory JavApiService() => _instance;

  JavApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OmniHub-Mobile/1.2.3',
        },
      ),
    );
  }

  static const String defaultBaseUrl = 'http://192.168.50.81:8923';
  late final Dio _dio;
  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    var url = newUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    _baseUrl = url;
    _dio.options.baseUrl = _baseUrl;
  }

  /// 获取探索流作品 (带分页与分类)
  Future<List<JavItem>> fetchExplore({
    int page = 1,
    String? type,
    String? magnetType,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (magnetType != null && magnetType.isNotEmpty) {
        queryParams['magnet'] = magnetType;
      }

      final res = await _dio.get('/api/jav/explore', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
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
            .whereType<Map<String, dynamic>>()
            .map((e) => JavItem.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('JavApiService.fetchExplore error: $e');
      return [];
    }
  }

  /// 获取番号完整详情 (包含 12 张样张、磁链等)
  Future<JavDetail?> fetchDetail(String code) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      final res = await _dio.get('/api/jav/detail/$cleanCode');
      if (res.statusCode == 200 && res.data != null && res.data is Map<String, dynamic>) {
        return JavDetail.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('JavApiService.fetchDetail error for $code: $e');
      return null;
    }
  }

  /// 获取热门女优列表
  Future<List<JavActress>> fetchActresses() async {
    try {
      final res = await _dio.get('/api/jav/actresses');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        List rawList = [];
        if (data is Map && data['actresses'] is List) {
          rawList = data['actresses'] as List;
        } else if (data is List) {
          rawList = data;
        }

        return rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => JavActress.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('JavApiService.fetchActresses error: $e');
      return [];
    }
  }

  /// 搜索番号或演员
  Future<List<JavItem>> search(String keyword, {int page = 1}) async {
    try {
      final res = await _dio.get(
        '/api/jav/search',
        queryParameters: {'q': keyword.trim(), 'page': page},
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        List rawList = [];
        if (data is Map && data['results'] is List) {
          rawList = data['results'] as List;
        } else if (data is List) {
          rawList = data;
        }
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => JavItem.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('JavApiService.search error: $e');
      return [];
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
