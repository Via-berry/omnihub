import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/download/controllers/download_controller.dart';
import 'package:moviepilot_mobile/modules/downloader/models/downloader_stats.dart';
import 'package:moviepilot_mobile/modules/subtitle/controllers/subtitle_search_controller.dart';
import 'package:moviepilot_mobile/modules/subtitle/models/subtitle_search_models.dart';
import 'package:moviepilot_mobile/utils/size_formatter.dart';
import 'package:moviepilot_mobile/widgets/bottom_sheet.dart';

class SubtitleDownloadSheet extends GetView<DownloadController> {
  const SubtitleDownloadSheet({super.key, required this.item});

  final SubtitleSearchItem item;

  SubtitleSearchController get _subtitleController =>
      Get.find<SubtitleSearchController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    final backgroundAlt =
        Color.lerp(background, scheme.primary, isDark ? 0.035 : 0.018) ??
        background;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BottomSheetWidget(
        header: Builder(builder: _buildHeader),
        scrollController: controller.scrollController,
        snap: false,
        snapSizes: const [],
        initialChildSize: 0.62,
        minChildSize: 0.28,
        maxChildSize: 0.86,
        builder: (context, scrollController) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [backgroundAlt, background],
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              _buildSummary(context),
              const SizedBox(height: 12),
              _buildDownloadSettingsSection(context),
              const SizedBox(height: 14),
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.text_bubble_fill,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '下载字幕',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final title = (item.title ?? '').trim().isEmpty ? '未命名字幕' : item.title!;
    final metas = <String>[
      if ((item.siteName ?? '').trim().isNotEmpty) item.siteName!.trim(),
      if ((item.language ?? '').trim().isNotEmpty) item.language!.trim(),
      if (item.size != null && item.size! > 0)
        SizeFormatter.formatSize(item.size, 1),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (metas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              metas.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadSettingsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '下载设置',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Obx(
            () => _buildSubsectionLabel(
              context,
              '下载器',
              controller.selectedDownloader.value?.name ?? '未选择',
            ),
          ),
          _buildDownloaderSelector(context),
          const SizedBox(height: 10),
          Obx(
            () => _buildSubsectionLabel(
              context,
              '保存目录',
              controller.selectedDirectory.value.isEmpty
                  ? '自动匹配'
                  : controller.selectedDirectory.value,
            ),
          ),
          _buildDirectorySelector(context),
        ],
      ),
    );
  }

  Widget _buildDownloaderSelector(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingDownloaders) {
        return _buildPlaceholderState(context, label: '正在加载');
      }
      final downloaders = controller.downloaders;
      final selected = controller.selectedDownloader.value;
      if (downloaders.isEmpty) {
        return _buildPlaceholderState(context, label: '暂无可用下载器');
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: downloaders.map((downloader) {
            final stats = controller.statsFor(downloader.name);
            final isSelected = selected?.name == downloader.name;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 188,
                height: 70,
                child: _buildChoiceTile(
                  context,
                  title: downloader.name,
                  subtitle: _downloaderSubtitle(downloader, stats),
                  isSelected: isSelected,
                  accentColor: Theme.of(context).colorScheme.primary,
                  onTap: () => controller.setDownloader(downloader),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildDirectorySelector(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedDirectory.value;
      final suggestions = controller.directorySuggestions;
      final entries = <String>['', ...suggestions];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: entries.map((dir) {
            final isAuto = dir.isEmpty;
            final label = isAuto ? '自动匹配' : dir;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: isAuto ? 116 : 164,
                height: 46,
                child: _buildChoiceTile(
                  context,
                  title: label,
                  isSelected: selected == dir,
                  accentColor: Theme.of(context).colorScheme.secondary,
                  onTap: () => controller.setDirectory(dir),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildBottomActions(BuildContext context) {
    return Obx(() {
      final enabled = controller.selectedDownloader.value != null;
      final busy = _subtitleController.downloadingKeys.contains(item.key);
      return SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: enabled && !busy
              ? () async {
                  final path = controller.selectedDirectory.value.trim();
                  final ok = await _subtitleController.downloadSubtitle(
                    item,
                    savePath: path.isEmpty ? null : path,
                  );
                  if (ok && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 19),
          label: Text(
            busy ? '下载中' : '开始下载',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    });
  }

  Widget _buildSubsectionLabel(
    BuildContext context,
    String title,
    String selectedValue,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.12)
                : _controlSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.22)
                  : scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? accentColor : scheme.outline,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? accentColor : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderState(BuildContext context, {required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _controlSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outlineColor(context)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _downloaderSubtitle(dynamic downloader, DownloaderStats? stats) {
    if (stats != null && stats.freeSpace > 0) {
      return '剩余 ${SizeFormatter.formatSize(stats.freeSpace, 1)}';
    }
    return downloader.type.isNotEmpty ? downloader.type.toUpperCase() : '';
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: theme.cardColor.withValues(alpha: isDark ? 0.90 : 0.98),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outlineColor(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.055),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Color _controlSurface(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.42 : 0.72,
    );
  }

  Color _outlineColor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7);
  }
}
