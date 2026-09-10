import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/gen/assets.gen.dart';
import 'package:moviepilot_mobile/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:moviepilot_mobile/modules/dashboard/pages/edit_dashboard_page.dart';
import 'package:moviepilot_mobile/modules/search/controllers/app_setting_controller.dart';
import 'package:moviepilot_mobile/theme/section.dart';
import 'package:moviepilot_mobile/utils/open_url.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:moviepilot_mobile/widgets/section_header.dart';

class AppSettingPage extends GetView<AppSettingController> {
  const AppSettingPage({super.key});

  static const String _repoUrl =
      'https://github.com/singleton-altman/MoviePilotLite';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildAppInfoCard(context),
          _buildAppearanceSection(context),
          _buildSearchAndDownloadSection(context),
          _buildBrowserSection(context),
          _buildAboutSection(context),
          _buildAppFooter(context),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Section(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.zero,
      header: const SectionHeader(title: '外观与首页', subtitle: '主题、背景、布局'),
      separatorBuilder: _buildDivider,
      children: [
        _buildNavigationTile(
          context,
          title: '主题风格',
          subtitle: '主题模式与主色设置',
          icon: Icons.palette_outlined,
          iconColor: CupertinoColors.activeBlue,
          onTap: () => Get.toNamed('/settings/app/theme-mode'),
        ),
        _buildNavigationTile(
          context,
          title: '背景图片',
          subtitle: '自定义应用背景与视觉氛围',
          icon: Icons.photo_outlined,
          iconColor: CupertinoColors.systemPurple,
          onTap: () => Get.toNamed('/settings/app/background-image'),
        ),
        _buildNavigationTile(
          context,
          title: '首页布局',
          subtitle: '编辑 Dashboard 的模块展示方式',
          icon: Icons.dashboard_customize_outlined,
          iconColor: CupertinoColors.systemTeal,
          onTap: () => _showEditDashboardModal(context),
        ),
      ],
    );
  }

  Widget _buildSearchAndDownloadSection(BuildContext context) {
    return Section(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.zero,
      header: const SectionHeader(title: '搜索与下载', subtitle: '入口、状态、直连'),
      separatorBuilder: _buildDivider,
      children: [
        Obx(
          () => _buildSwitchTile(
            context,
            title: '搜索按钮',
            subtitle: '控制首页是否展示快捷搜索入口',
            icon: Icons.search,
            iconColor: CupertinoColors.activeBlue,
            value: controller.showSearchButton.value,
            onChanged: controller.updateShowSearchButton,
          ),
        ),
        Obx(
          () => _buildSwitchTile(
            context,
            title: '搜索页入库状态',
            subtitle: '在搜索结果中显示媒体库收录状态',
            icon: Icons.video_library_outlined,
            iconColor: CupertinoColors.systemGreen,
            value: controller.enableFetchMediaserverLibraryStatus.value,
            onChanged: controller.updateEnableFetchMediaserverLibraryStatus,
          ),
        ),
        Obx(
          () => _buildSwitchTile(
            context,
            title: '下载器直连下载',
            subtitle: '下载前先保存本地种子文件并跳转直连下载页',
            icon: Icons.bolt_outlined,
            iconColor: CupertinoColors.systemOrange,
            value: controller.enableSpecialDownload.value,
            onChanged: (value) async {
              if (!value) {
                controller.updateEnableSpecialDownload(false);
                return;
              }
              ToastUtil.warning(
                '由于站点特殊性，下载器直连下载暂不能保证适配所有站点。如有特殊需求，请提交 PR。',
                onConfirm: () => controller.updateEnableSpecialDownload(true),
                onCancel: () => controller.updateEnableSpecialDownload(false),
              );
            },
          ),
        ),
        Obx(
          () => _buildSwitchTile(
            context,
            title: '下载器管理',
            subtitle: '由 App 直接连接下载器，不经过 MoviePilot 服务器',
            icon: Icons.download_outlined,
            iconColor: CupertinoColors.systemIndigo,
            value: controller.enableDownloaderManager.value,
            onChanged: (value) async {
              if (!value) {
                controller.updateEnableDownloaderManager(false);
                return;
              }
              ToastUtil.warning(
                '已启用 app 种子管理：请求由 App 直连下载器，不经过 MoviePilot 服务器，请确保网络可达。',
                onConfirm: () => controller.updateEnableDownloaderManager(true),
                onCancel: () => controller.updateEnableDownloaderManager(false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrowserSection(BuildContext context) {
    return Section(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.zero,
      header: const SectionHeader(title: '浏览与实验', subtitle: '兼容性与访问方式'),
      separatorBuilder: _buildDivider,
      children: [
        Obx(
          () => _buildSwitchTile(
            context,
            title: '使用外部浏览器',
            subtitle: '部分站点场景下可获得更好的兼容性',
            icon: Icons.public,
            iconColor: CupertinoColors.systemPink,
            value: controller.useExternalBrowser.value,
            onChanged: controller.updateUseExternalBrowser,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Section(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.zero,
      header: const SectionHeader(title: '关于应用', subtitle: '版本、构建与开源信息'),
      separatorBuilder: _buildDivider,
      children: [
        Obx(() {
          final hasNew = controller.hasNewVersion;
          final isChecking = controller.isCheckingUpdate.value;
          final isDownloading = controller.isDownloadingUpdate.value;
          final currentVer = controller.version.value;
          final latestVer = controller.latestVersionLabel;

          String subtitle;
          Widget? trailingBadge;

          if (isDownloading) {
            final percent = (controller.downloadProgress.value * 100)
                .clamp(0, 100)
                .toStringAsFixed(0);
            subtitle = '正在下载更新安装包...';
            trailingBadge = Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeBlue,
              ),
            );
          } else if (isChecking) {
            subtitle = '正在检查版本更新...';
            trailingBadge = const CupertinoActivityIndicator(radius: 8);
          } else if (hasNew) {
            subtitle = '发现新版本 $latestVer · 点击查看并升级';
            trailingBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CupertinoColors.systemOrange.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '可更新',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemOrange,
                    ),
                  ),
                ],
              ),
            );
          } else {
            final patch = controller.currentPatchLabel;
            subtitle = '当前已是最新版本${patch != null ? " ($patch)" : ""} · 点击检查';
            trailingBadge = Text(
              'v$currentVer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }

          return _buildSettingTile(
            context,
            title: '版本更新',
            subtitle: subtitle,
            icon: Icons.system_update_alt_rounded,
            iconColor: hasNew
                ? CupertinoColors.systemOrange
                : CupertinoColors.systemBlue,
            additionalWidget: trailingBadge,
            trailing: const CupertinoListTileChevron(),
            onTap: () => controller.handleVersionTap(context),
          );
        }),
        Obx(() {
          final baseline = controller.upstreamBaseline.value;
          final check = controller.upstreamCheckResult.value;
          final isChecking = controller.isCheckingUpstream.value;
          final hasUpdate = check?.hasUpdate == true;

          Widget? trailingBadge;
          if (isChecking) {
            trailingBadge = const CupertinoActivityIndicator(radius: 8);
          } else if (hasUpdate) {
            trailingBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CupertinoColors.systemOrange.withValues(alpha: 0.32),
                ),
              ),
              child: const Text(
                '有上游新版',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemOrange,
                ),
              ),
            );
          } else {
            trailingBadge = Text(
              baseline.baselineTag,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }

          final subtitle = hasUpdate
              ? '发现上游新版本 ${check?.latestTag} · 点击查看与同步'
              : '基线: MoviePilotLite ${baseline.shortSummary} · 点击查看详情';

          return _buildSettingTile(
            context,
            title: '上游代码基线',
            subtitle: subtitle,
            icon: Icons.merge_type_rounded,
            iconColor: hasUpdate
                ? CupertinoColors.systemOrange
                : CupertinoColors.systemPurple,
            additionalWidget: trailingBadge,
            trailing: const CupertinoListTileChevron(),
            onTap: () => controller.showUpstreamDetailSheet(context),
          );
        }),
        Obx(() {
          final run = controller.latestWorkflowRun.value;
          String subtitle = '查看 GitHub Actions 热更新与打包状态';
          String? infoText;
          if (run != null) {
            if (run.isBuilding) {
              subtitle = 'Shorebird Patch #${run.runNumber} · 正在打包中';
              infoText = '打包中 ⏳';
            } else if (run.isQueued) {
              subtitle = 'Shorebird Patch #${run.runNumber} · 排队中';
              infoText = '排队中';
            } else if (run.isSuccess) {
              subtitle = '最新构建已完成 · ${run.timeAgo}';
              infoText = '已完成 ✓';
            } else if (run.isFailed) {
              subtitle = '最新构建失败 · ${run.timeAgo}';
              infoText = '失败 ✕';
            }
          }
          return _buildNavigationTile(
            context,
            title: '热更新构建进度',
            subtitle: subtitle,
            icon: Icons.bolt_rounded,
            iconColor: run?.isBuilding == true
                ? CupertinoColors.activeBlue
                : CupertinoColors.systemTeal,
            additionalInfo: infoText,
            onTap: () => Get.toNamed('/settings/app/workflow-status'),
          );
        }),
        _buildNavigationTile(
          context,
          title: '更新日志',
          subtitle: '查看版本演进与功能更新记录',
          icon: Icons.history_rounded,
          iconColor: CupertinoColors.systemOrange,
          onTap: () => Get.toNamed('/settings/app/changelog'),
        ),
        _buildNavigationTile(
          context,
          title: '开源仓库',
          subtitle: 'GitHub · singleton-altman/MoviePilotLite',
          icon: Icons.code_rounded,
          iconColor: CupertinoColors.systemIndigo,
          trailing: const Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: CupertinoColors.systemGrey,
          ),
          onTap: () => WebUtil.open(url: _repoUrl, internal: false),
        ),
      ],
    );
  }

  Widget _buildAppInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Obx(() {
      final hasNew = controller.hasNewVersion;
      final patchLabel = controller.currentPatchLabel;
      final isChecking = controller.isCheckingUpdate.value;
      final isDownloading = controller.isDownloadingUpdate.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.22)),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Assets.logo.svg(
                      colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MoviePilot',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${controller.version.value}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '移动端设置与体验偏好',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: onSurface.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.handleVersionTap(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: hasNew
                        ? CupertinoColors.systemOrange.withValues(alpha: 0.10)
                        : primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasNew
                          ? CupertinoColors.systemOrange.withValues(alpha: 0.32)
                          : primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasNew
                            ? Icons.new_releases_rounded
                            : (isChecking
                                ? Icons.sync_rounded
                                : (isDownloading
                                    ? Icons.downloading_rounded
                                    : Icons.verified_rounded)),
                        size: 18,
                        color: hasNew
                            ? CupertinoColors.systemOrange
                            : (isChecking
                                ? primary
                                : (isDownloading
                                    ? CupertinoColors.activeGreen
                                    : primary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasNew
                              ? '发现新版本 ${controller.latestVersionLabel} · 点击立即更新'
                              : (isChecking
                                  ? '正在检查版本更新...'
                                  : (isDownloading
                                      ? '正在下载更新安装包 (${(controller.downloadProgress.value * 100).toStringAsFixed(0)}%)'
                                      : '当前已是最新版本${patchLabel != null ? " · $patchLabel" : ""}')),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                hasNew ? FontWeight.w600 : FontWeight.w500,
                            color: hasNew
                                ? CupertinoColors.systemOrange
                                : onSurface.withValues(alpha: 0.82),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: hasNew
                            ? CupertinoColors.systemOrange
                            : onSurface.withValues(alpha: 0.36),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAppFooter(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Column(
          children: [
            Text(
              'MoviePilot 移动端助手',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: onSurface.withValues(alpha: 0.38),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Copyright © 2026 Altman. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: onSurface.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
    String? additionalInfo,
    Widget? additionalWidget,
    Widget? trailing,
  }) {
    return _buildSettingTile(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      additionalInfo: additionalInfo,
      additionalWidget: additionalWidget,
      trailing:
          trailing ?? (onTap != null ? const CupertinoListTileChevron() : null),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSettingTile(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        padding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
    VoidCallback? onTap,
    String? additionalInfo,
    Widget? additionalWidget,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tile = CupertinoListTile.notched(
      padding: const EdgeInsetsDirectional.only(
        start: 14,
        end: 12,
        top: 8,
        bottom: 8,
      ),
      leading: _buildLeadingIcon(context, icon: icon, color: iconColor),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
            )
          : null,
      additionalInfo: additionalWidget ??
          (additionalInfo != null
              ? Text(
                  additionalInfo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null),
      trailing: trailing,
      onTap: onTap,
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildLeadingIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 0.1,
      color: Theme.of(context).dividerColor,
      indent: 58,
      endIndent: 16,
    );
  }

  Future<void> _showEditDashboardModal(BuildContext context) async {
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => const EditDashboardPage(),
    );
  }
}
