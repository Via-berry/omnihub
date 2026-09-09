import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/settings/models/github_workflow_models.dart';
import 'package:moviepilot_mobile/modules/settings/services/github_actions_service.dart';
import 'package:moviepilot_mobile/utils/open_url.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class WorkflowStatusController extends GetxController {
  final GithubActionsService _service = GithubActionsService.instance;

  final allRuns = <WorkflowRun>[].obs;
  final selectedRun = Rxn<WorkflowRun>();
  final jobs = <WorkflowJob>[].obs;

  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingJobs = false.obs;
  final errorMessage = RxnString();

  final selectedWorkflowFilter = '全部'.obs;
  final autoPollEnabled = true.obs;
  final lastRefreshTime = Rxn<DateTime>();

  Timer? _pollTimer;
  Timer? _durationTimer;
  final currentElapsedDuration = Rxn<Duration>();

  List<String> get availableWorkflows {
    final names = {'全部'};
    for (final run in allRuns) {
      if (run.name.isNotEmpty) {
        names.add(run.name);
      }
    }
    return names.toList();
  }

  List<WorkflowRun> get filteredRuns {
    final filter = selectedWorkflowFilter.value;
    if (filter == '全部') {
      return allRuns;
    }
    return allRuns.where((r) => r.name == filter).toList();
  }

  WorkflowRun? get activeOrSelectedRun => selectedRun.value ?? filteredRuns.firstOrNull;

  List<WorkflowStep> get activeSteps {
    if (jobs.isEmpty) return const [];
    return jobs.first.steps;
  }

  @override
  void onInit() {
    super.onInit();
    loadInitial();
    _startDurationTicker();
  }

  @override
  void onClose() {
    _stopPolling();
    _durationTimer?.cancel();
    super.onClose();
  }

  Future<void> loadInitial() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _fetchRunsInternal(forceRefresh: true);
      final target = activeOrSelectedRun;
      if (target != null) {
        await _fetchJobsForRun(target.id, forceRefresh: true);
      }
      _checkAndSetupPolling();
    } catch (e) {
      errorMessage.value = '加载构建信息失败，请下拉重试';
    } finally {
      isLoading.value = false;
      lastRefreshTime.value = DateTime.now();
    }
  }

  Future<void> refreshData({bool showToast = false}) async {
    isRefreshing.value = true;
    try {
      await _fetchRunsInternal(forceRefresh: true);
      final target = activeOrSelectedRun;
      if (target != null) {
        await _fetchJobsForRun(target.id, forceRefresh: true);
      }
      lastRefreshTime.value = DateTime.now();
      _checkAndSetupPolling();
      if (showToast) {
        ToastUtil.success('构建状态已刷新');
      }
    } catch (e) {
      if (showToast) {
        ToastUtil.error('刷新失败，请稍后重试');
      }
    } finally {
      isRefreshing.value = false;
    }
  }

  void selectRun(WorkflowRun run) {
    if (selectedRun.value?.id == run.id) return;
    selectedRun.value = run;
    _fetchJobsForRun(run.id, forceRefresh: false);
  }

  void setFilter(String filter) {
    selectedWorkflowFilter.value = filter;
    if (selectedRun.value != null && !filteredRuns.contains(selectedRun.value)) {
      selectedRun.value = filteredRuns.firstOrNull;
    }
    final target = activeOrSelectedRun;
    if (target != null) {
      _fetchJobsForRun(target.id);
    }
  }

  Future<void> _fetchRunsInternal({bool forceRefresh = false}) async {
    final runs = await _service.fetchWorkflowRuns(perPage: 25, forceRefresh: forceRefresh);
    allRuns.assignAll(runs);

    final currentSelected = selectedRun.value;
    if (currentSelected != null) {
      final updated = runs.firstWhereOrNull((r) => r.id == currentSelected.id);
      if (updated != null) {
        selectedRun.value = updated;
      }
    }
  }

  Future<void> _fetchJobsForRun(int runId, {bool forceRefresh = false}) async {
    isLoadingJobs.value = true;
    try {
      final fetchedJobs = await _service.fetchJobsForRun(runId, forceRefresh: forceRefresh);
      jobs.assignAll(fetchedJobs);
    } finally {
      isLoadingJobs.value = false;
    }
  }

  void _checkAndSetupPolling() {
    final active = activeOrSelectedRun;
    final needPoll = autoPollEnabled.value && active != null && (active.isBuilding || active.isQueued);

    if (needPoll) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final beforeStatus = activeOrSelectedRun?.status;
      await _fetchRunsInternal(forceRefresh: true);
      final target = activeOrSelectedRun;
      if (target != null) {
        await _fetchJobsForRun(target.id, forceRefresh: true);
      }

      final after = activeOrSelectedRun;
      if (beforeStatus == 'in_progress' && after != null && !after.isBuilding) {
        if (after.isSuccess) {
          ToastUtil.success('🎉 热更新已打包发布完成！');
        } else if (after.isFailed) {
          ToastUtil.error('⚠️ 热更新构建打包失败');
        }
      }
      _checkAndSetupPolling();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final target = activeOrSelectedRun;
      if (target != null) {
        currentElapsedDuration.value = target.duration;
      }
    });
  }

  void openInBrowser(String url) {
    WebUtil.open(url: url, internal: false);
  }
}
