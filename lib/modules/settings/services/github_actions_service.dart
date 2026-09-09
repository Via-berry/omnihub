import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/applog/app_log.dart';
import 'package:moviepilot_mobile/modules/settings/models/github_workflow_models.dart';

class GithubActionsService extends GetxService {
  static GithubActionsService get instance =>
      Get.isRegistered<GithubActionsService>()
          ? Get.find<GithubActionsService>()
          : Get.put(GithubActionsService(), permanent: true);

  static const String owner = 'Via-berry';
  static const String repo = 'omnihub';
  static const String baseUrl = 'https://api.github.com/repos/$owner/$repo';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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

  final Map<int, (List<WorkflowJob> jobs, DateTime cachedAt)> _jobsCache = {};

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
      final response = await _dio.get<dynamic>(
        '$baseUrl/actions/runs',
        queryParameters: {'per_page': perPage},
      );

      final data = response.data;
      final rawList = data is Map ? data['workflow_runs'] : null;
      if (rawList is! List) return _cachedRuns ?? const [];

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

      _cachedRuns = runs;
      _cachedRunsTime = DateTime.now();
      return runs;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '获取 GitHub Actions 工作流列表失败');
      return _cachedRuns ?? const [];
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
      final response = await _dio.get<dynamic>('$baseUrl/actions/runs/$runId/jobs');
      final data = response.data;
      final rawJobs = data is Map ? data['jobs'] : null;
      if (rawJobs is! List) return cached?.jobs ?? const [];

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

      _jobsCache[runId] = (jobs, DateTime.now());
      return jobs;
    } catch (e, st) {
      _log.handle(e, stackTrace: st, message: '获取工作流 Jobs 详情失败');
      return cached?.jobs ?? const [];
    }
  }
}
