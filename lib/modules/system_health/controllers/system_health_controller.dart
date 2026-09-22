import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:moviepilot_mobile/applog/app_log.dart';
import 'package:moviepilot_mobile/services/api_client.dart';
import 'package:moviepilot_mobile/services/app_service.dart';

enum SystemHealthStatus {
  idle,
  checking,
  ok,
  warning,
  error,
  disabled,
  unknown,
}

class SystemHealthItem {
  SystemHealthItem({
    required this.id,
    required this.title,
    this.status = SystemHealthStatus.idle,
    this.detail,
    this.message,
    this.lastCheckedAt,
  });

  final String id;
  final String title;
  SystemHealthStatus status;
  String? detail;
  String? message;
  DateTime? lastCheckedAt;
}

class SystemHealthController extends GetxController {
  static const String _moduleListEndpoint = '/api/v1/system/modulelist';
  static const String _moduleTestEndpointBase = '/api/v1/system/moduletest';
  static const List<String> _healthEndpoints = [
    '/api/v1/system/health',
    '/api/v1/system/healthcheck',
    '/api/v1/system/health-check',
    '/api/v1/system/health_check',
    '/api/v1/system/check',
  ];

  final _log = Get.find<AppLog>();
  final _apiClient = Get.find<ApiClient>();
  final _appService = Get.find<AppService>();

  final isLoading = false.obs;
  final lastRunAt = Rxn<DateTime>();
  final errorMessage = RxnString();
  final items = <SystemHealthItem>[].obs;

  String? _resolvedEndpoint;

  @override
  void onReady() {
    super.onReady();
    fetchHealth();
  }

  Future<void> fetchHealth() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final token =
          _apiClient.token ?? _appService.latestLoginProfileAccessToken;
      if (token == null || token.isEmpty) {
        errorMessage.value = '缺少 Token，请重新登录';
        items.clear();
        return;
      }

      final moduleList = await _fetchModuleList(token);
      if (moduleList.isNotEmpty) {
        items.assignAll(moduleList);
        await _runModuleTests(token);
        lastRunAt.value = DateTime.now();
        return;
      }

      final response = await _requestHealth(token);
      if (response == null) {
        errorMessage.value = '无法连接健康检查接口';
        items.clear();
        return;
      }

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 400) {
        errorMessage.value = '请求失败 (HTTP $statusCode)';
      }

      final parsed = _parseItems(response.data);
      if (parsed.isEmpty) {
        if (errorMessage.value == null) {
          errorMessage.value = '未获取到健康检查数据';
        }
        items.clear();
      } else {
        items.assignAll(parsed);
        lastRunAt.value = DateTime.now();
      }
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '系统健康检查异常');
      errorMessage.value = '请求异常';
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<SystemHealthItem>> _fetchModuleList(String token) async {
    try {
      final response = await _apiClient.get<dynamic>(
        _moduleListEndpoint,
        token: token,
      );
      final payload = _decodePayload(response.data);
      if (payload == null) return const [];
      if (payload['success'] == false) {
        return const [];
      }
      final list = _extractModuleList(payload);
      if (list.isEmpty) return const [];
      return _parseModuleList(list);
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '获取模块列表失败');
      return const [];
    }
  }

  Future<Response<dynamic>?> _requestHealth(String token) async {
    final endpoints = <String>[
      if (_resolvedEndpoint != null) _resolvedEndpoint!,
      ..._healthEndpoints,
    ];
    Response<dynamic>? lastResponse;
    for (final endpoint in endpoints.toSet()) {
      try {
        final response = await _apiClient.get<dynamic>(
          endpoint,
          token: token,
          timeout: 10,
        );
        lastResponse = response;
        final statusCode = response.statusCode ?? 0;
        if (statusCode != 404) {
          _resolvedEndpoint = endpoint;
          return response;
        }
      } catch (_) {
        // ignore and try next endpoint
      }
    }
    return lastResponse;
  }

  Future<void> _runModuleTests(String token) async {
    if (items.isEmpty) return;
    for (final item in items) {
      _updateItem(item, (target) {
        target.status = SystemHealthStatus.checking;
        target.message = null;
        target.detail = null;
      });
    }

    var hasFailure = false;
    for (final item in items) {
      final success = await _testModule(item, token);
      if (!success) hasFailure = true;
    }
    if (hasFailure && errorMessage.value == null) {
      errorMessage.value = '部分模块检测失败';
    }
  }

  Future<bool> _testModule(SystemHealthItem item, String token) async {
    try {
      final endpoint =
          '$_moduleTestEndpointBase/${Uri.encodeComponent(item.id)}';
      final response = await _apiClient.get<dynamic>(
        endpoint,
        token: token,
        timeout: 15,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 400) {
        _updateItem(item, (target) {
          target.status = SystemHealthStatus.error;
          target.message = 'HTTP $statusCode';
          target.detail = null;
          target.lastCheckedAt = DateTime.now();
        });
        return false;
      }

      final result = _parseModuleTestResponse(response.data);
      _updateItem(item, (target) {
        target.status = result.status;
        target.message = result.message;
        target.detail = result.detail;
        target.lastCheckedAt = DateTime.now();
      });
      return result.status != SystemHealthStatus.error;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '模块检测失败: ${item.title}');
      _updateItem(item, (target) {
        target.status = SystemHealthStatus.error;
        target.message = '请求异常';
        target.detail = null;
        target.lastCheckedAt = DateTime.now();
      });
      return false;
    }
  }

  List<SystemHealthItem> _parseItems(dynamic data) {
    if (data == null) return const [];
    final payload = _decodePayload(data);
    if (payload == null) {
      if (data is List) {
        return _parseList(data);
      }
      return const [];
    }

    final list = _extractList(payload);
    if (list.isNotEmpty) {
      return _parseList(list);
    }

    final moduleMap = _extractModuleMap(payload);
    if (moduleMap != null && moduleMap.isNotEmpty) {
      return _parseModuleMap(moduleMap);
    }

    return const [];
  }

  List<SystemHealthItem> _parseList(List<dynamic> list) {
    final results = <SystemHealthItem>[];
    for (var i = 0; i < list.length; i += 1) {
      final item = _parseItem(list[i], fallbackId: 'item-$i');
      if (item != null) results.add(item);
    }
    return results;
  }

  List<SystemHealthItem> _parseModuleMap(Map<String, dynamic> map) {
    final results = <SystemHealthItem>[];
    map.forEach((key, value) {
      final item = _parseItem(value, fallbackId: key, fallbackTitle: key);
      if (item != null) results.add(item);
    });
    return results;
  }

  List<SystemHealthItem> _parseModuleList(List<dynamic> list) {
    final results = <SystemHealthItem>[];
    for (var i = 0; i < list.length; i += 1) {
      final raw = list[i];
      final map = _toMap(raw);
      if (map == null) {
        final title = raw?.toString() ?? 'module-$i';
        results.add(
          SystemHealthItem(
            id: 'module-$i',
            title: title,
            status: SystemHealthStatus.idle,
          ),
        );
        continue;
      }

      final id = _stringValue(
            map['id'],
            fallback: _stringValue(map['key']),
          ) ??
          'module-$i';
      final title = _stringValue(
            map['name'],
            fallback: _stringValue(map['title'], fallback: id),
          ) ??
          id;

      final enabled = _parseBool(
        map['enabled'] ??
            map['enable'] ??
            map['active'] ??
            map['is_enabled'] ??
            map['isEnabled'],
      );
      final statusValue = map['status'] ??
          map['state'] ??
          map['health'] ??
          map['ok'] ??
          map['success'] ??
          map['result'];

      var status = _mapStatus(statusValue, enabled: enabled);
      if (status == SystemHealthStatus.unknown) {
        status = SystemHealthStatus.idle;
      }

      results.add(
        SystemHealthItem(
          id: id,
          title: title,
          status: status,
        ),
      );
    }
    return results;
  }

  _ModuleTestResult _parseModuleTestResponse(dynamic data) {
    final payload = _decodePayload(data);
    if (payload == null) {
      if (data is String && data.trim().isNotEmpty) {
        final mapped = _mapStatusFromText(data);
        return _ModuleTestResult(
          status: mapped ?? SystemHealthStatus.unknown,
          message: data,
        );
      }
      return const _ModuleTestResult(
        status: SystemHealthStatus.unknown,
        message: '响应解析失败',
      );
    }

    final success = payload['success'];
    final message = payload['message']?.toString();
    final detail = payload['detail']?.toString();

    SystemHealthStatus status;
    if (success is bool) {
      if (success) {
        status = _mapStatusFromText(message) ?? SystemHealthStatus.ok;
      } else {
        if (message == null || message.trim().isEmpty) {
          status = SystemHealthStatus.disabled;
        } else {
          status = _mapStatusFromText(message) ?? SystemHealthStatus.error;
        }
      }
    } else {
      status = _mapStatusFromText(message) ?? SystemHealthStatus.unknown;
    }

    return _ModuleTestResult(status: status, message: message, detail: detail);
  }

  SystemHealthItem? _parseItem(
    dynamic raw, {
    String? fallbackId,
    String? fallbackTitle,
  }) {
    if (raw == null) return null;

    final map = _toMap(raw);
    if (map == null) {
      final title = fallbackTitle ?? raw.toString();
      final status = _mapStatus(raw);
      return SystemHealthItem(
        id: fallbackId ?? title,
        title: title,
        status: status,
      );
    }

    final id =
        _stringValue(
          map['id'],
          fallback: _stringValue(
            map['key'],
            fallback: _stringValue(
              map['name'],
              fallback: fallbackId ?? 'unknown',
            ),
          ),
        ) ??
        fallbackId ??
        'unknown';
    final title =
        _stringValue(
          map['title'],
          fallback: _stringValue(map['name'], fallback: fallbackTitle ?? id),
        ) ??
        id;

    final enabled = _parseBool(
      map['enabled'] ??
          map['enable'] ??
          map['active'] ??
          map['is_enabled'] ??
          map['isEnabled'],
    );

    final statusValue =
        map['status'] ??
        map['state'] ??
        map['health'] ??
        map['ok'] ??
        map['success'] ??
        map['result'];

    final message = _stringValue(
      map['message'],
      fallback: _stringValue(map['summary']),
    );
    final detail = _stringValue(
      map['detail'],
      fallback: _stringValue(
        map['error'],
        fallback: _stringValue(map['reason']),
      ),
    );

    final status = _mapStatus(
      statusValue,
      enabled: enabled,
      messageHint: message ?? detail,
    );

    return SystemHealthItem(
      id: id,
      title: title,
      status: status,
      message: message,
      detail: detail,
      lastCheckedAt: DateTime.now(),
    );
  }

  void _updateItem(
    SystemHealthItem item,
    void Function(SystemHealthItem target) update,
  ) {
    update(item);
    items.refresh();
  }

  SystemHealthStatus _mapStatus(
    dynamic status, {
    bool? enabled,
    String? messageHint,
  }) {
    if (enabled == false) return SystemHealthStatus.disabled;
    if (status == null) {
      return _mapStatusFromText(messageHint) ?? SystemHealthStatus.unknown;
    }
    if (status is bool) {
      return status ? SystemHealthStatus.ok : SystemHealthStatus.error;
    }
    if (status is num) {
      final value = status.toInt();
      if (value <= -1) return SystemHealthStatus.disabled;
      if (value == 0) return SystemHealthStatus.error;
      if (value == 1) return SystemHealthStatus.ok;
      if (value == 2) return SystemHealthStatus.warning;
      if (value == 3) return SystemHealthStatus.disabled;
    }
    if (status is String) {
      final mapped = _mapStatusFromText(status);
      if (mapped != null) return mapped;
    }
    return SystemHealthStatus.unknown;
  }

  SystemHealthStatus? _mapStatusFromText(String? text) {
    if (text == null) return null;
    final value = text.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (_containsAny(value, ['disabled', 'off', '未启用', '未开启', '禁用'])) {
      return SystemHealthStatus.disabled;
    }
    if (_containsAny(value, ['checking', 'testing', 'pending', '检测'])) {
      return SystemHealthStatus.checking;
    }
    if (_containsAny(value, ['warn', 'warning', 'degraded', '偏慢', '警告'])) {
      return SystemHealthStatus.warning;
    }
    if (_containsAny(value, [
      'error',
      'fail',
      'failed',
      '异常',
      '错误',
      '不可用',
      'down',
    ])) {
      return SystemHealthStatus.error;
    }
    if (_containsAny(value, [
      'ok',
      'normal',
      'healthy',
      'success',
      '正常',
      '运行中',
      'up',
    ])) {
      return SystemHealthStatus.ok;
    }
    return null;
  }

  List<dynamic> _extractModuleList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final modules = data['modules'] ?? data['items'] ?? data['list'];
      if (modules is List) return modules;
    }
    if (data is List) return data;
    final modules = payload['modules'];
    if (modules is List) return modules;
    return const [];
  }

  bool _containsAny(String input, List<String> keys) {
    for (final key in keys) {
      if (input.contains(key.toLowerCase())) return true;
    }
    return false;
  }

  Map<String, dynamic>? _decodePayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<dynamic> _extractList(Map<String, dynamic> payload) {
    final direct = payload['data'];
    if (direct is List) return direct;

    final candidates = [
      payload['items'],
      payload['list'],
      payload['modules'],
      payload['checks'],
      payload['results'],
      direct,
    ];

    for (final candidate in candidates) {
      if (candidate is List) return candidate;
      if (candidate is Map<String, dynamic>) {
        for (final key in ['items', 'list', 'modules', 'checks', 'results']) {
          final nested = candidate[key];
          if (nested is List) return nested;
        }
      }
    }
    return const [];
  }

  Map<String, dynamic>? _extractModuleMap(Map<String, dynamic> payload) {
    final candidates = [
      payload['modules'],
      payload['data'],
      payload['items'],
      payload['list'],
      payload['checks'],
      payload['results'],
    ];
    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) return candidate;
      if (candidate is Map) return Map<String, dynamic>.from(candidate);
    }
    return null;
  }

  Map<String, dynamic>? _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? _stringValue(dynamic value, {String? fallback}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (['true', '1', 'yes', 'y', 'on', 'enabled'].contains(normalized)) {
        return true;
      }
      if (['false', '0', 'no', 'n', 'off', 'disabled'].contains(normalized)) {
        return false;
      }
    }
    return null;
  }
}

class _ModuleTestResult {
  const _ModuleTestResult({
    required this.status,
    this.message,
    this.detail,
  });

  final SystemHealthStatus status;
  final String? message;
  final String? detail;
}
