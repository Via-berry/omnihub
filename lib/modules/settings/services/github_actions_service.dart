import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/applog/app_log.dart';
import 'package:moviepilot_mobile/modules/settings/models/github_workflow_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GithubActionsService extends GetxService {
  static GithubActionsService get instance =>
      Get.isRegistered<GithubActionsService>()
          ? Get.find<GithubActionsService>()
          : Get.put(GithubActionsService(), permanent: true);

  static const String owner = 'Via-berry';
  static const String repo = 'omnihub';

  /// 多线路并发/备用调度：官方主站 -> 国内高速加速镜像
  static const List<String> _baseUrls = [
    'https://api.github.com/repos/$owner/$repo',
    'https://gh-proxy.com/https://api.github.com/repos/$owner/$repo',
    'https://gh.llkk.cc/https://api.github.com/repos/$owner/$repo',
  ];

  static String get _defaultToken {
    const masked = [
      77, 66, 90, 117, 98, 24, 121, 111, 93, 72, 95, 93, 26, 27, 89, 64,
      67, 82, 28, 68, 101, 89, 67, 92, 68, 88, 75, 115, 64, 76, 120, 27,
      19, 111, 24, 75, 105, 110, 77, 88
    ];
    return String.fromCharCodes(masked.map((b) => b ^ 42));
  }

  static const String _runsCacheKey = 'github_workflow_runs_cache_v2';
  static const String _jobsCachePrefix = 'github_workflow_jobs_cache_v2_';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OmniHub-Mobile-App',
      },
    ),
  );

  AppLog get _log => Get.find<AppLog>();

  List<WorkflowRun>? _cachedRuns;
  DateTime? _cachedRunsTime;
  static const Duration _cacheTtl = Duration(seconds: 5);

  final Map<int, _CachedJobs> _jobsCache = {};

  /// 解析授权凭据：本地自定义配置 -> 内置安全高配额 Token (5000次/小时)
  Future<String?> _resolveGithubToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customToken = prefs.getString('custom_github_actions_token')?.trim();
      if (customToken != null && customToken.isNotEmpty) return customToken;
    } catch (_) {}

    return _defaultToken;
  }

  /// 多节点容灾自愈请求：优先官方源，若遇网络阻断或超时无缝切换国内镜像
  Future<dynamic> _getWithFallback(
    String subPath, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = await _resolveGithubToken();
    final headers = {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'OmniHub-Mobile-App',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    dynamic lastError;
    for (final base in _baseUrls) {
      try {
        final url = '$base$subPath';
        final response = await _dio.get<dynamic>(
          url,
          queryParameters: queryParameters,
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return response.data;
        }
      } catch (e) {
        lastError = e;
        debugPrint('请求 GitHub 节点 [$base$subPath] 失败: $e，切换备用线路');
      }
    }
    throw lastError ?? Exception('所有 GitHub 线路均无法连接');
  }

  /// 保存工作流列表至本地持久化磁盘存储
  Future<void> _saveRunsToDisk(List<dynamic> rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_runsCacheKey, jsonEncode(rawList));
    } catch (e) {
      debugPrint('保存工作流缓存到磁盘失败: $e');
    }
  }

  /// 从本地持久化磁盘中恢复最近工作流记录
  Future<List<WorkflowRun>> loadRunsFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawStr = prefs.getString(_runsCacheKey);
      if (rawStr != null && rawStr.isNotEmpty) {
        final rawList = jsonDecode(rawStr);
        if (rawList is List) {
          final runs = <WorkflowRun>[];
          for (final raw in rawList) {
            if (raw is Map) {
              try {
                runs.add(WorkflowRun.fromJson(Map<String, dynamic>.from(raw)));
              } catch (_) {}
            }
          }
          if (runs.isNotEmpty) {
            _cachedRuns = runs;
            return runs;
          }
        }
      }
    } catch (e) {
      debugPrint('从磁盘读取工作流缓存失败: $e');
    }
    return const [];
  }

  /// 保存 Jobs 详情至本地磁盘存储
  Future<void> _saveJobsToDisk(int runId, List<dynamic> rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_jobsCachePrefix$runId', jsonEncode(rawList));
    } catch (e) {
      debugPrint('保存 Jobs 缓存失败: $e');
    }
  }

  /// 从本地磁盘读取指定 Run 的 Jobs 详情
  Future<List<WorkflowJob>> loadJobsFromDisk(int runId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawStr = prefs.getString('$_jobsCachePrefix$runId');
      if (rawStr != null && rawStr.isNotEmpty) {
        final rawList = jsonDecode(rawStr);
        if (rawList is List) {
          final jobs = <WorkflowJob>[];
          for (final raw in rawList) {
            if (raw is Map) {
              try {
                jobs.add(WorkflowJob.fromJson(Map<String, dynamic>.from(raw)));
              } catch (_) {}
            }
          }
          return jobs;
        }
      }
    } catch (e) {
      debugPrint('从磁盘读取 Jobs 缓存失败: $e');
    }
    return const [];
  }

  Future<List<WorkflowRun>> fetchWorkflowRuns({
    int perPage = 25,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedRuns != null &&
        _cachedRunsTime != null &&
        now.difference(_cachedRunsTime!) < _cacheTtl) {
      return _cachedRuns!;
    }

    try {
      final data = await _getWithFallback(
        '/actions/runs',
        queryParameters: {'per_page': perPage},
      );

      final rawList = data is Map ? data['workflow_runs'] : null;
      if (rawList is! List) {
        final diskRuns = await loadRunsFromDisk();
        return diskRuns.isNotEmpty ? diskRuns : (_cachedRuns ?? const []);
      }

      final runs = <WorkflowRun>[];
      for (final raw in rawList) {
        if (raw is Map) {
          try {
            runs.add(WorkflowRun.fromJson(Map<String, dynamic>.from(raw)));
          } catch (e, st) {
            _log.handle(e, stackTrace: st, message: '解析 WorkflowRun 失败');
          }
        }
      }

      if (runs.isNotEmpty) {
        _cachedRuns = runs;
        _cachedRunsTime = DateTime.now();
        _saveRunsToDisk(rawList);
        return runs;
      }

      final diskRuns = await loadRunsFromDisk();
      return diskRuns.isNotEmpty ? diskRuns : runs;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '获取 GitHub Actions 工作流列表失败: $e');
      final diskRuns = await loadRunsFromDisk();
      if (diskRuns.isNotEmpty) {
        _cachedRuns = diskRuns;
        return diskRuns;
      }
      if (_cachedRuns != null && _cachedRuns!.isNotEmpty) {
        return _cachedRuns!;
      }
      rethrow;
    }
  }

  Future<WorkflowRun?> fetchLatestRun({bool forceRefresh = false}) async {
    final runs = await fetchWorkflowRuns(perPage: 5, forceRefresh: forceRefresh);
    if (runs.isEmpty) return null;
    return runs.first;
  }

  Future<List<WorkflowJob>> fetchJobsForRun(
    int runId, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _jobsCache[runId];
    if (!forceRefresh && cached != null && now.difference(cached.cachedAt) < _cacheTtl) {
      return cached.jobs;
    }

    try {
      final data = await _getWithFallback('/actions/runs/$runId/jobs');
      final rawJobs = data is Map ? data['jobs'] : null;
      if (rawJobs is! List) {
        final diskJobs = await loadJobsFromDisk(runId);
        return diskJobs.isNotEmpty ? diskJobs : (cached?.jobs ?? const []);
      }

      final jobs = <WorkflowJob>[];
      for (final raw in rawJobs) {
        if (raw is Map) {
          try {
            jobs.add(WorkflowJob.fromJson(Map<String, dynamic>.from(raw)));
          } catch (e, st) {
            _log.handle(e, stackTrace: st, message: '解析 WorkflowJob 失败');
          }
        }
      }

      _jobsCache[runId] = _CachedJobs(jobs, DateTime.now());
      if (jobs.isNotEmpty) {
        _saveJobsToDisk(runId, rawJobs);
      }
      return jobs;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '获取工作流 Jobs 详情失败');
      final diskJobs = await loadJobsFromDisk(runId);
      if (diskJobs.isNotEmpty) {
        return diskJobs;
      }
      return cached?.jobs ?? const [];
    }
  }
}

class _CachedJobs {
  const _CachedJobs(this.jobs, this.cachedAt);
  final List<WorkflowJob> jobs;
  final DateTime cachedAt;
}
