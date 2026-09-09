import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/settings/controllers/workflow_status_controller.dart';
import 'package:moviepilot_mobile/modules/settings/models/github_workflow_models.dart';
import 'package:skeletonizer/skeletonizer.dart';

class WorkflowStatusPage extends GetView<WorkflowStatusController> {
  const WorkflowStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('热更新构建进度'),
        centerTitle: false,
        actions: [
          Obx(() {
            return IconButton(
              icon: controller.isRefreshing.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: '刷新构建状态',
              onPressed: controller.isRefreshing.value
                  ? null
                  : () => controller.refreshData(showToast: true),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (controller.errorMessage.value != null && controller.allRuns.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => controller.loadInitial(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final activeRun = controller.activeOrSelectedRun;
        if (activeRun == null) {
          return const Center(child: Text('暂无工作流构建记录'));
        }

        return RefreshIndicator(
          onRefresh: controller.refreshData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildActiveRunCard(context, activeRun),
              const SizedBox(height: 20),
              _buildPipelineStepsCard(context, activeRun),
              const SizedBox(height: 20),
              _buildHistoryHeader(context),
              const SizedBox(height: 10),
              _buildWorkflowFilterBar(context),
              const SizedBox(height: 10),
              _buildHistoryList(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActiveRunCard(BuildContext context, WorkflowRun run) {
    final theme = Theme.of(context);
    final statusColor = run.statusColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (run.isBuilding)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(run.statusIcon, size: 14, color: statusColor),
                        ),
                      Text(
                        run.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  run.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Commit Title
            Text(
              run.displayTitle.isNotEmpty ? run.displayTitle : run.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Meta Info Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(
                  context,
                  icon: Icons.alt_route_rounded,
                  label: run.headBranch,
                  color: theme.colorScheme.primary,
                ),
                _buildTag(
                  context,
                  icon: Icons.tag_rounded,
                  label: '#${run.runNumber}',
                ),
                if (run.shortSha.isNotEmpty)
                  _buildTag(
                    context,
                    icon: Icons.commit_rounded,
                    label: run.shortSha,
                  ),
                if (run.actorName != null && run.actorName!.isNotEmpty)
                  _buildTag(
                    context,
                    icon: Icons.person_outline_rounded,
                    label: run.actorName!,
                  ),
                _buildTag(
                  context,
                  icon: Icons.access_time_rounded,
                  label: run.formattedStartTime,
                ),
                Obx(() {
                  controller.currentElapsedDuration.value;
                  return _buildTag(
                    context,
                    icon: Icons.timer_outlined,
                    label: run.formattedDuration,
                    color: run.isBuilding ? statusColor : null,
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('在 GitHub 查看'),
                    onPressed: () => controller.openInBrowser(run.htmlUrl),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('刷新'),
                  onPressed: () => controller.refreshData(showToast: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStepsCard(BuildContext context, WorkflowRun run) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '流水线步骤明细',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (controller.isLoadingJobs.value)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '${controller.activeSteps.length} 个步骤',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.activeSteps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    controller.isLoadingJobs.value ? '正在加载流水线步骤...' : '暂无执行步骤信息',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ...List.generate(controller.activeSteps.length, (index) {
                final step = controller.activeSteps[index];
                final isLast = index == controller.activeSteps.length - 1;
                return _buildStepRow(context, step, isLast: isLast);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, WorkflowStep step, {required bool isLast}) {
    final theme = Theme.of(context);
    final statusColor = step.statusColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (step.isBuilding)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: statusColor,
                    ),
                  )
                else
                  Icon(step.statusIcon, size: 18, color: statusColor),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Step content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: step.isBuilding ? FontWeight.w700 : FontWeight.w500,
                        color: step.isBuilding
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: step.isSkipped ? 0.4 : 0.9,
                              ),
                      ),
                    ),
                  ),
                  if (step.formattedDuration.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.formattedDuration,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: step.isBuilding
                              ? statusColor
                              : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '历史构建',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        Obx(() {
          return Text(
            '共 ${controller.filteredRuns.length} 次记录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkflowFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final workflows = controller.availableWorkflows;
    if (workflows.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: workflows.map((name) {
          final isSelected = controller.selectedWorkflowFilter.value == name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                name.length > 18 ? '${name.substring(0, 16)}...' : name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => controller.setFilter(name),
              showCheckmark: false,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    final runs = controller.filteredRuns;
    if (runs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '该分类下暂无构建记录',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Column(
      children: runs.map((run) {
        final isSelected = controller.activeOrSelectedRun?.id == run.id;
        return _buildHistoryItem(context, run, isSelected: isSelected);
      }).toList(),
    );
  }

  Widget _buildHistoryItem(BuildContext context, WorkflowRun run, {required bool isSelected}) {
    final theme = Theme.of(context);
    final statusColor = run.statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? statusColor.withValues(alpha: 0.06) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? statusColor.withValues(alpha: 0.4) : theme.dividerColor.withValues(alpha: 0.2),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.selectRun(run),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(run.statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${run.runNumber} ${run.displayTitle.isNotEmpty ? run.displayTitle : run.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          run.headBranch,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '·',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          run.formattedStartTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '·',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          run.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '查看中',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? theme.dividerColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
