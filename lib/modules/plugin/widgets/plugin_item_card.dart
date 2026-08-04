import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dashboard/widgets/dashboard_widget_styles.dart';
import 'package:moviepilot_mobile/modules/plugin/models/plugin_models.dart';
import 'package:moviepilot_mobile/modules/plugin/services/plugin_palette_cache.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

enum PluginHandleType { settings, reset, uninstall, log, web }

class PluginItemCard extends StatelessWidget {
  const PluginItemCard({
    super.key,
    required this.item,
    required this.iconUrl,
    required this.installCount,
    this.onHandleTap,
  });

  final PluginItem item;
  final String iconUrl;
  final int installCount;
  final Function(PluginHandleType type)? onHandleTap;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    final installedView = onHandleTap != null;

    return Obx(() {
      final accent = _resolveAccent(palette);
      final status = _statusPresentation(palette, installedView);

      return Semantics(
        button: true,
        label: '${item.pluginName}，${status.label}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: palette.isDark ? 0.18 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: palette.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
              side: BorderSide(
                color: Color.alphaBlend(
                  accent.withValues(alpha: palette.isDark ? 0.28 : 0.22),
                  palette.tileBorder,
                ),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      accent.withValues(alpha: palette.isDark ? 0.22 : 0.14),
                      palette.surface,
                    ),
                    Color.alphaBlend(
                      accent.withValues(alpha: palette.isDark ? 0.08 : 0.04),
                      palette.pageBackgroundAlt,
                    ),
                    palette.surface,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: accent,
                        child: const SizedBox(width: 4),
                      ),
                    ),
                    Positioned(
                      right: -18,
                      top: -22,
                      child: IgnorePointer(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(
                                  alpha: palette.isDark ? 0.20 : 0.14,
                                ),
                                accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildIcon(context, accent, palette),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.pluginName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.25,
                                        height: 1.2,
                                        color: palette.titleText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _metaLine,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.25,
                                        fontWeight: FontWeight.w500,
                                        color: palette.mutedText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusBadge(
                                label: status.label,
                                color: status.color,
                                icon: status.icon,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.pluginDesc?.trim().isNotEmpty == true
                                ? item.pluginDesc!.trim()
                                : '暂无插件说明',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: palette.bodyText.withValues(
                                alpha: palette.isDark ? 0.78 : 0.82,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              _MetaChip(
                                icon: CupertinoIcons.arrow_down_circle_fill,
                                label: _formatInstallCount(installCount),
                                color: accent,
                                palette: palette,
                              ),
                              if (_labelList.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: _MetaChip(
                                    icon: CupertinoIcons.tag_fill,
                                    label: _labelList.first,
                                    color: palette.coolAccent,
                                    palette: palette,
                                  ),
                                ),
                              ],
                              if (item.isLocal) ...[
                                const SizedBox(width: 6),
                                _MetaChip(
                                  icon: CupertinoIcons.device_laptop,
                                  label: '本地',
                                  color: palette.warmAccent,
                                  palette: palette,
                                ),
                              ],
                              const Spacer(),
                              if (onHandleTap != null)
                                _buildMenu(context, palette, accent)
                              else
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 14,
                                    color: accent,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  String get _metaLine {
    final author = item.pluginAuthor?.trim().isNotEmpty == true
        ? item.pluginAuthor!.trim()
        : '未知作者';
    final version = (item.pluginVersion ?? '').trim();
    if (version.isEmpty) return author;
    return '$author · v$version';
  }

  Color _resolveAccent(DashboardPaletteData palette) {
    try {
      final cache = Get.find<PluginPaletteCache>();
      if (iconUrl.isEmpty) {
        // keep Obx subscribed even without icon URL
        cache.getCached('__noop__');
        return palette.primary;
      }
      return cache.watchColor(iconUrl) ??
          cache.getCached(iconUrl) ??
          PluginPaletteCache.defaultColor;
    } catch (_) {
      return palette.primary;
    }
  }

  Widget _buildIcon(
    BuildContext context,
    Color accent,
    DashboardPaletteData palette,
  ) {
    final fallback = ColoredBox(
      color: accent.withValues(alpha: 0.16),
      child: Icon(Icons.extension_rounded, size: 22, color: accent),
    );
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl.isEmpty
          ? fallback
          : CachedImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              memCacheWidth: 96,
              memCacheHeight: 96,
              placeholder: fallback,
              errorWidget: fallback,
            ),
    );
  }

  Widget _statusBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(
    BuildContext context,
    DashboardPaletteData palette,
    Color accent,
  ) {
    return PopupMenuButton<PluginHandleType>(
      tooltip: '插件操作',
      padding: EdgeInsets.zero,
      onSelected: onHandleTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 18,
          color: accent,
        ),
      ),
      itemBuilder: (context) => PluginHandleType.values
          .map(
            (type) => PopupMenuItem(
              value: type,
              child: Row(
                children: [
                  Icon(
                    _getHandleTypeIcon(type),
                    size: 18,
                    color: _getHandleTypeColor(context, type, palette),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getHandleTypeLabel(type),
                    style: TextStyle(
                      color: _getHandleTypeColor(context, type, palette),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  ({String label, IconData icon, Color color}) _statusPresentation(
    DashboardPaletteData palette,
    bool installedView,
  ) {
    if (item.hasUpdate) {
      return (
        label: '可更新',
        icon: CupertinoIcons.arrow_up_circle_fill,
        color: palette.warningAccent,
      );
    }
    if (installedView) {
      return item.state
          ? (
              label: '运行中',
              icon: CupertinoIcons.checkmark_seal_fill,
              color: palette.successAccent,
            )
          : (
              label: '已停用',
              icon: CupertinoIcons.pause_circle_fill,
              color: palette.mutedText,
            );
    }
    if (item.installed) {
      return (
        label: '已安装',
        icon: CupertinoIcons.checkmark_circle_fill,
        color: palette.successAccent,
      );
    }
    return (
      label: '可安装',
      icon: CupertinoIcons.plus_circle_fill,
      color: palette.primary,
    );
  }

  List<String> get _labelList {
    final raw = item.pluginLabel;
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();
  }

  String _formatInstallCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  String _getHandleTypeLabel(PluginHandleType type) {
    switch (type) {
      case PluginHandleType.settings:
        return '设置';
      case PluginHandleType.log:
        return '日志';
      case PluginHandleType.reset:
        return '重置';
      case PluginHandleType.uninstall:
        return '卸载';
      case PluginHandleType.web:
        return '作者主页';
    }
  }

  IconData _getHandleTypeIcon(PluginHandleType type) {
    switch (type) {
      case PluginHandleType.settings:
        return CupertinoIcons.settings;
      case PluginHandleType.log:
        return CupertinoIcons.doc_text;
      case PluginHandleType.reset:
        return CupertinoIcons.restart;
      case PluginHandleType.uninstall:
        return CupertinoIcons.delete;
      case PluginHandleType.web:
        return CupertinoIcons.compass;
    }
  }

  Color _getHandleTypeColor(
    BuildContext context,
    PluginHandleType type,
    DashboardPaletteData palette,
  ) {
    if (type == PluginHandleType.uninstall) {
      return Theme.of(context).colorScheme.error;
    }
    return palette.titleText;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final Color color;
  final DashboardPaletteData palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
