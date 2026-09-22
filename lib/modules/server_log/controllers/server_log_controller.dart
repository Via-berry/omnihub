import 'dart:async';

import 'package:get/get.dart';
import 'package:moviepilot_mobile/applog/app_log.dart';
import 'package:moviepilot_mobile/modules/login/repositories/auth_repository.dart';
import 'package:moviepilot_mobile/services/api_client.dart';

/// 服务器日志控制器
///
/// 后续可以在这里扩展：
/// - 实时拉取服务端日志
/// - 过滤 / 搜索 / 关键字高亮
/// - 与 Dashboard 中的捷径联动等
class ServerLogController extends GetxController {
  final _apiClient = Get.find<ApiClient>();
  final _log = Get.find<AppLog>();
  final _authRepository = Get.find<AuthRepository>();
  String logFile = 'moviepilot.log';
  String title = '服务器';

  /// 是否正在加载日志
  final isLoading = false.obs;

  /// 是否已建立流连接
  final isStreaming = false.obs;

  /// 是否处于等待新日志的空闲状态
  final isIdle = false.obs;

  /// 日志级别过滤（ALL/INFO/WARN/ERROR/DEBUG）
  final filterLevel = 'ALL'.obs;

  /// 关键字搜索
  final keyword = ''.obs;

  /// 日志内容（简单占位，后续可以换成更复杂的数据结构）
  final logs = <LogEntry>[].obs;

  StreamSubscription<String>? _subscription;
  DateTime? _lastEventAt;
  Timer? _idleTimer;
  final List<LogEntry> _pendingBatch = [];
  bool _isFlushScheduled = false;

  @override
  void onReady() {
    super.onReady();
    startLogStream();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _idleTimer?.cancel();
    _pendingBatch.clear();
    super.onClose();
  }

  void _flushPendingLogs() {
    if (isClosed || _pendingBatch.isEmpty) return;
    final batch = List<LogEntry>.from(_pendingBatch);
    _pendingBatch.clear();

    final combined = <LogEntry>[...batch, ...logs];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    const maxLines = 500;
    if (combined.length > maxLines) {
      combined.removeRange(maxLines, combined.length);
    }
    logs.assignAll(combined);
  }

  /// 启动实时日志流，从 /api/v1/system/logging 订阅 SSE。
  Future<void> startLogStream({bool allowRefresh = true}) async {
    isLoading.value = true;
    logs.clear();
    _pendingBatch.clear();
    await _subscription?.cancel();
    isStreaming.value = false;
    isIdle.value = true;
    _lastEventAt = null;
    _startIdleTimer();
    try {
      final stream = await _apiClient.streamLines(
        '/api/v1/system/logging?logfile=$logFile',
      );
      _subscription = stream.listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;

          // SSE 形如: data: <payload>
          String payload = trimmed;
          if (payload.startsWith('data:')) {
            payload = payload.substring(5).trimLeft();
          }

          _lastEventAt = DateTime.now();
          if (!isStreaming.value) {
            isStreaming.value = true;
          }
          isIdle.value = false;

          final entry = LogEntry.fromLine(payload);
          _pendingBatch.add(entry);

          if (!_isFlushScheduled) {
            _isFlushScheduled = true;
            scheduleMicrotask(() {
              _isFlushScheduled = false;
              _flushPendingLogs();
            });
          }
        },
        onError: (e, st) {
          _flushPendingLogs();
          _log.handle(e, stackTrace: st, message: '实时日志流订阅失败');
          isLoading.value = false;
          isStreaming.value = false;
          isIdle.value = false;
        },
        onDone: () {
          _flushPendingLogs();
          isLoading.value = false;
          isStreaming.value = false;
          isIdle.value = false;
          _log.info('实时日志流已结束');
        },
      );
      // 订阅建立后即可展示页面，避免等待流结束
      isLoading.value = false;
    } on ApiAuthException catch (e, st) {
      _log.handle(e, stackTrace: st, message: '实时日志流鉴权失败，尝试刷新 Token');
      if (allowRefresh && await _refreshToken()) {
        return startLogStream(allowRefresh: false);
      }
      isLoading.value = false;
      isStreaming.value = false;
      isIdle.value = false;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '启动实时日志流失败');
      isLoading.value = false;
      isStreaming.value = false;
      isIdle.value = false;
    }
  }

  /// 仅用于断开后手动重连
  Future<void> reconnect() async {
    await _subscription?.cancel();
    await startLogStream(allowRefresh: true);
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isStreaming.value) {
        isIdle.value = false;
        return;
      }
      final last = _lastEventAt;
      if (last == null) {
        isIdle.value = true;
        return;
      }
      isIdle.value =
          DateTime.now().difference(last) > const Duration(seconds: 3);
    });
  }

  Future<bool> _refreshToken() async {
    try {
      final profiles = await _authRepository.getProfilesAsync();
      if (profiles.isEmpty) return false;
      profiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final latest = profiles.first;
      await _authRepository.login(
        server: latest.server,
        username: latest.username,
        password: latest.password,
      );
      return true;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '刷新 Token 失败');
      return false;
    }
  }

  List<LogEntry> get filteredLogs {
    final level = filterLevel.value.toUpperCase();
    final key = keyword.value.trim().toLowerCase();
    return logs.where((e) {
      if (level != 'ALL' && e.level.toUpperCase() != level) {
        return false;
      }
      if (key.isNotEmpty && !e.searchContent.contains(key)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class LogEntry {
  LogEntry({
    required this.level,
    required this.timestamp,
    required this.module,
    required this.message,
    required this.raw,
    String? searchContent,
  }) : searchContent = searchContent ??
            '$level $module $message $raw'.toLowerCase();

  final String level;
  final DateTime timestamp;
  final String module;
  final String message;
  final String raw;
  final String searchContent;

  static final RegExp _pattern = RegExp(
    r'^[【\[]([A-Z]+)[】\]]\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3})\s*-\s*(.+?)\s*-\s*(.*)$',
  );

  factory LogEntry.fromLine(String line) {
    final match = _pattern.firstMatch(line);
    if (match == null) {
      return LogEntry(
        level: 'INFO',
        timestamp: DateTime.now(),
        module: 'unknown',
        message: line,
        raw: line,
        searchContent: 'info unknown $line $line'.toLowerCase(),
      );
    }

    final level = match.group(1) ?? 'INFO';
    final timeStr = match.group(2) ?? '';
    final module = (match.group(3) ?? 'unknown').trim();
    final message = (match.group(4) ?? '').trim();

    DateTime parsedTime;
    try {
      final normalized = timeStr.replaceFirst(',', '.').replaceFirst(' ', 'T');
      parsedTime = DateTime.parse(normalized);
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return LogEntry(
      level: level,
      timestamp: parsedTime,
      module: module,
      message: message,
      raw: line,
      searchContent: '$level $module $message $line'.toLowerCase(),
    );
  }
}
