import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dashboard/widgets/dashboard_widget_styles.dart';
import 'package:moviepilot_mobile/modules/plugin/controllers/plugin_controller.dart';
import 'package:moviepilot_mobile/modules/plugin/models/plugin_backup_models.dart';
import 'package:moviepilot_mobile/modules/plugin/models/plugin_models.dart';
import 'package:moviepilot_mobile/utils/image_util.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:moviepilot_mobile/widgets/app_loading.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

Future<void> showPluginBackupCenterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.36,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: PluginBackupCenterSheet(scrollController: scrollController),
        );
      },
    ),
  );
}

Future<void> showPluginBackupSelectSheet(
  BuildContext context,
  PluginBackupFile backup,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.42,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: PluginBackupSelectSheet(
            backup: backup,
            scrollController: scrollController,
          ),
        );
      },
    ),
  );
}

class PluginBackupCenterSheet extends StatefulWidget {
  const PluginBackupCenterSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<PluginBackupCenterSheet> createState() =>
      _PluginBackupCenterSheetState();
}

class _PluginBackupCenterSheetState extends State<PluginBackupCenterSheet> {
  final _controller = Get.find<PluginController>();

  bool _loadingList = true;
  bool _openingBackup = false;
  String? _errorText;
  List<PluginBackupListItem> _backups = const [];

  @override
  void initState() {
    super.initState();
    _reloadBackupList();
  }

  Future<void> _reloadBackupList() async {
    setState(() {
      _loadingList = true;
      _errorText = null;
    });
    try {
      final list = await _controller.listPluginBackups();
      if (!mounted) return;
      setState(() {
        _backups = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '读取本地备份失败';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingList = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final palette = DashboardPalette.of(context);

    return Material(
      color: palette.pageBackground,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _SheetHeader(
              palette: palette,
              title: '备份中心',
              onClose: () => Get.back(),
            ),
            Expanded(
              child: Obx(() {
                final backingUp = _controller.isBackingUp.value;
                final busy = backingUp || _openingBackup;
                return ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    20 + bottomSafe + bottomInset,
                  ),
                  children: [
                    _InfoBanner(
                      palette: palette,
                      icon: Icons.info_outline_rounded,
                      text:
                          '在此备份已安装插件、导入 JSON，或从本地备份恢复。缺仓库地址时会自动反推并多仓尝试。',
                    ),
                    const SizedBox(height: 14),
                    _PrimaryActionButton(
                      palette: palette,
                      icon: Icons.backup_outlined,
                      label: backingUp ? '备份中…' : '立即备份',
                      loading: backingUp,
                      onPressed: busy ? null : _backupNow,
                    ),
                    const SizedBox(height: 10),
                    _PrimaryActionButton(
                      palette: palette,
                      icon: Icons.file_open_outlined,
                      label: _openingBackup ? '读取中…' : '导入 JSON',
                      onPressed: busy ? null : _importFromFile,
                      outlined: true,
                      loading: _openingBackup,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '本地备份',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: palette.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loadingList)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: AppLoadingCenter.small(message: '读取本地备份…'),
                      )
                    else if (_errorText != null)
                      _InfoBanner(
                        palette: palette,
                        icon: Icons.error_outline_rounded,
                        text: _errorText!,
                        accent: Theme.of(context).colorScheme.error,
                      )
                    else if (_backups.isEmpty)
                      _EmptyBackupCard(palette: palette)
                    else
                      for (var i = 0; i < _backups.length; i++) ...[
                        _BackupFileCard(
                          palette: palette,
                          item: _backups[i],
                          onTap: busy
                              ? () {}
                              : () => _openBackup(_backups[i].filePath),
                          onDelete: () => _deleteBackup(_backups[i]),
                        ),
                        if (i != _backups.length - 1)
                          const SizedBox(height: 10),
                      ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow() async {
    try {
      final saved = await _controller.backupInstalledPlugins();
      if (!mounted) return;
      ToastUtil.success('已备份 ${saved.plugins.length} 个插件');
      await _reloadBackupList();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _openSelectSheet(PluginBackupFile backup) async {
    if (!mounted) return;
    await showPluginBackupSelectSheet(context, backup);
  }

  Future<void> _openBackup(String path) async {
    setState(() {
      _openingBackup = true;
      _errorText = null;
    });
    try {
      final backup = await _controller.readPluginBackup(path);
      if (!mounted) return;
      setState(() {
        _openingBackup = false;
      });
      await _openSelectSheet(backup);
    } catch (_) {
      if (!mounted) return;
      ToastUtil.error('读取备份失败');
      setState(() {
        _openingBackup = false;
      });
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (file.path == null || file.path!.isEmpty) {
          ToastUtil.error('无法读取所选文件');
          return;
        }
        final backup = await _controller.readPluginBackup(file.path!);
        if (!mounted) return;
        await _openSelectSheet(backup);
        return;
      }
      final backup = await _controller.readPluginBackupBytes(
        bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      await _openSelectSheet(backup);
    } catch (_) {
      ToastUtil.error('导入备份失败');
    }
  }

  Future<void> _deleteBackup(PluginBackupListItem item) async {
    final confirmed = await Get.dialog<bool>(
      _DeleteBackupDialog(item: item),
      barrierDismissible: true,
    );
    if (confirmed != true) return;
    await _controller.deletePluginBackup(item.filePath);
    await _reloadBackupList();
  }
}

class PluginBackupSelectSheet extends StatefulWidget {
  const PluginBackupSelectSheet({
    super.key,
    required this.backup,
    this.scrollController,
  });

  final PluginBackupFile backup;
  final ScrollController? scrollController;

  @override
  State<PluginBackupSelectSheet> createState() =>
      _PluginBackupSelectSheetState();
}

class _PluginBackupSelectSheetState extends State<PluginBackupSelectSheet> {
  final _controller = Get.find<PluginController>();
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller.restoreProgress.value = null;
    final installedIds = _controller.items.map((e) => e.id).toSet();
    _selectedIds.addAll(
      widget.backup.plugins
          .where(
            (e) =>
                (e.repoUrl ?? '').trim().isNotEmpty &&
                !installedIds.contains(e.id),
          )
          .map((e) => e.id),
    );
  }

  @override
  void dispose() {
    if (!_controller.isRestoring.value) {
      _controller.restoreProgress.value = null;
    }
    super.dispose();
  }

  Future<void> _startRestore() async {
    if (_selectedIds.isEmpty) return;
    final selected = widget.backup.plugins
        .where((e) => _selectedIds.contains(e.id))
        .toList();
    try {
      await _controller.restorePlugins(selected);
    } catch (e) {
      ToastUtil.error(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final palette = DashboardPalette.of(context);
    final selectable = widget.backup.plugins
        .where((e) => (e.repoUrl ?? '').trim().isNotEmpty)
        .toList();

    return Material(
      color: palette.pageBackground,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _SheetHeader(
              palette: palette,
              title: '选择要恢复的插件',
              onClose: () {
                if (_controller.isRestoring.value) return;
                Get.back();
              },
            ),
            Expanded(
              child: Obx(() {
                final localById = <String, PluginItem>{
                  for (final item in _controller.items) item.id: item,
                };
                final restoring = _controller.isRestoring.value;
                final progress = _controller.restoreProgress.value;
                final installingId =
                    restoring && progress != null && !progress.done
                    ? progress.currentId
                    : '';
                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  children: [
                    Row(
                      children: [
                        _ChipButton(
                          palette: palette,
                          label: '全选',
                          onPressed: restoring || selectable.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(selectable.map((e) => e.id));
                                  });
                                },
                        ),
                        const SizedBox(width: 8),
                        _ChipButton(
                          palette: palette,
                          label: '清空',
                          onPressed: restoring
                              ? null
                              : () => setState(_selectedIds.clear),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(
                              alpha: palette.isDark ? 0.18 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '已选 ${_selectedIds.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < widget.backup.plugins.length; i++) ...[
                      _PluginSelectCard(
                        palette: palette,
                        item: widget.backup.plugins[i],
                        selected: _selectedIds.contains(
                          widget.backup.plugins[i].id,
                        ),
                        localItem: localById[widget.backup.plugins[i].id],
                        installing:
                            installingId == widget.backup.plugins[i].id,
                        hasRepo:
                            (widget.backup.plugins[i].repoUrl ?? '')
                                .trim()
                                .isNotEmpty,
                        interactive: !restoring,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              _selectedIds.add(widget.backup.plugins[i].id);
                            } else {
                              _selectedIds.remove(
                                widget.backup.plugins[i].id,
                              );
                            }
                          });
                        },
                      ),
                      if (i != widget.backup.plugins.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                );
              }),
            ),
            Obx(() {
              final restoring = _controller.isRestoring.value;
              final progress = _controller.restoreProgress.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.pageBackgroundAlt,
                  border: Border(top: BorderSide(color: palette.tileBorder)),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomSafe),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (progress != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.done ? 1 : progress.ratio,
                            minHeight: 6,
                            backgroundColor: palette.primary.withValues(
                              alpha: 0.12,
                            ),
                            color: progress.done && progress.failedCount > 0
                                ? Theme.of(context).colorScheme.error
                                : palette.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress.done
                              ? '完成 ${progress.total}/${progress.total}'
                              : '正在安装 ${progress.currentIndex + 1}/${progress.total}'
                                    '${progress.currentName.isEmpty ? '' : '：${progress.currentName}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.mutedText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '成功 ${progress.successCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.successAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '失败 ${progress.failedCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: progress.failedCount > 0
                                    ? Theme.of(context).colorScheme.error
                                    : palette.mutedText,
                              ),
                            ),
                            if (progress.done) ...[
                              const Spacer(),
                              Text(
                                '已完成',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.titleText,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      _PrimaryActionButton(
                        palette: palette,
                        icon: Icons.install_desktop_rounded,
                        label: restoring
                            ? '恢复中…'
                            : progress != null && progress.done
                            ? '再次安装（${_selectedIds.length}）'
                            : '安装选中（${_selectedIds.length}）',
                        loading: restoring,
                        onPressed: restoring || _selectedIds.isEmpty
                            ? null
                            : _startRestore,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.palette,
    required this.title,
    required this.onClose,
  });

  final DashboardPaletteData palette;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: palette.mutedText.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: palette.titleText,
                  ),
                ),
              ),
              _HeaderIconButton(
                palette: palette,
                icon: CupertinoIcons.xmark,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.palette,
    required this.icon,
    required this.onPressed,
  });

  final DashboardPaletteData palette;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceAlt.withValues(alpha: palette.isDark ? 0.55 : 0.8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: palette.titleText),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.palette,
    required this.icon,
    required this.text,
    this.accent,
  });

  final DashboardPaletteData palette;
  final IconData icon;
  final String text;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? palette.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: palette.bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBackupCard extends StatelessWidget {
  const _EmptyBackupCard({required this.palette});

  final DashboardPaletteData palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: palette.pageBackgroundAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.tileBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.folder_open_outlined,
              color: palette.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无本地备份',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.titleText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点上方「立即备份」或「导入 JSON」开始。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: palette.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.loading = false,
  });

  final DashboardPaletteData palette;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.primary,
            side: BorderSide(
              color: palette.primary.withValues(alpha: enabled ? 0.45 : 0.2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onPrimary,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: palette.primary.withValues(alpha: 0.28),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.72),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.palette,
    required this.label,
    required this.onPressed,
  });

  final DashboardPaletteData palette;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.tileBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: onPressed == null
                  ? palette.faintText
                  : palette.titleText,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupFileCard extends StatelessWidget {
  const _BackupFileCard({
    required this.palette,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final DashboardPaletteData palette;
  final PluginBackupListItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const double _hPad = 12;
  static const double _icon = 44;
  static const double _gap = 12;
  static const double _chevron = 28;

  @override
  Widget build(BuildContext context) {
    final time =
        '${item.createdAt.year.toString().padLeft(4, '0')}-'
        '${item.createdAt.month.toString().padLeft(2, '0')}-'
        '${item.createdAt.day.toString().padLeft(2, '0')} '
        '${item.createdAt.hour.toString().padLeft(2, '0')}:'
        '${item.createdAt.minute.toString().padLeft(2, '0')}';
    final card = Material(
      color: palette.pageBackgroundAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.tileBorder),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _icon,
                height: _icon,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.coolAccent.withValues(
                    alpha: palette.isDark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: palette.coolAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.3,
                        color: palette.titleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$time · ${item.pluginCount} 个插件',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: palette.mutedText,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );

    return CupertinoContextMenu.builder(
      enableHapticFeedback: true,
      actions: [
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          trailingIcon: CupertinoIcons.delete,
          onPressed: () {
            Navigator.of(context).pop();
            onDelete();
          },
          child: const Text('删除备份'),
        ),
      ],
      builder: (context, animation) {
        final maxWidth = MediaQuery.sizeOf(context).width - 32;
        final textWidth =
            maxWidth - _hPad - _icon - _gap - _chevron - 8;
        final namePainter = TextPainter(
          text: TextSpan(
            text: item.fileName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.3,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: textWidth.clamp(80, maxWidth));
        final height = (24 + namePainter.height + 4 + 18 + 12)
            .clamp(72.0, MediaQuery.sizeOf(context).height * 0.32);
        namePainter.dispose();
        return SizedBox(
          width: maxWidth,
          height: height,
          child: card,
        );
      },
    );
  }
}

class _PluginSelectCard extends StatelessWidget {
  const _PluginSelectCard({
    required this.palette,
    required this.item,
    required this.selected,
    required this.localItem,
    required this.installing,
    required this.hasRepo,
    required this.interactive,
    required this.onChanged,
  });

  final DashboardPaletteData palette;
  final PluginItem item;
  final bool selected;
  final PluginItem? localItem;
  final bool installing;
  final bool hasRepo;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final iconUrl = item.pluginIcon != null && item.pluginIcon!.isNotEmpty
        ? ImageUtil.convertPluginIconUrl(item.pluginIcon!)
        : '';
    final backupVersion = (item.pluginVersion ?? '').trim();
    final localVersion = (localItem?.pluginVersion ?? '').trim();
    final versionDiffer =
        localItem != null &&
        backupVersion.isNotEmpty &&
        localVersion.isNotEmpty &&
        backupVersion != localVersion;
    final repoUrl = (item.repoUrl ?? '').trim();
    final author = (item.pluginAuthor ?? '').trim();
    final canTap = interactive && hasRepo && !installing;
    final borderColor = installing
        ? palette.primary.withValues(alpha: 0.55)
        : selected
        ? palette.primary.withValues(alpha: 0.5)
        : palette.tileBorder;
    final bg = installing || selected
        ? Color.alphaBlend(
            palette.primary.withValues(alpha: palette.isDark ? 0.18 : 0.08),
            palette.pageBackgroundAlt,
          )
        : palette.pageBackgroundAlt;

    return Opacity(
      opacity: hasRepo || installing || selected ? 1 : 0.48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canTap ? () => onChanged(!selected) : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: installing || selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: installing || selected
                      ? palette.primary.withValues(alpha: 0.12)
                      : palette.shadow,
                  blurRadius: installing || selected ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: installing || selected
                        ? palette.primary
                        : palette.primary.withValues(alpha: 0.18),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedImage(
                                  imageUrl: iconUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (installing)
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: palette.surface.withValues(
                                      alpha: 0.72,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: palette.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.pluginName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.25,
                                          color: palette.titleText,
                                        ),
                                      ),
                                    ),
                                    if (installing) ...[
                                      const SizedBox(width: 8),
                                      _VersionChip(
                                        palette: palette,
                                        icon: Icons.downloading_rounded,
                                        label: '安装中',
                                        color: palette.primary,
                                        emphasized: true,
                                      ),
                                    ] else if (hasRepo) ...[
                                      const SizedBox(width: 8),
                                      _SelectMark(
                                        palette: palette,
                                        selected: selected,
                                      ),
                                    ],
                                  ],
                                ),
                                if (author.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: palette.mutedText,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (backupVersion.isNotEmpty)
                                      _VersionChip(
                                        palette: palette,
                                        icon: Icons.inventory_2_outlined,
                                        label: '备份 $backupVersion',
                                        color: palette.coolAccent,
                                      ),
                                    if (localVersion.isNotEmpty)
                                      _VersionChip(
                                        palette: palette,
                                        icon: Icons.phone_iphone_rounded,
                                        label: '本地 $localVersion',
                                        color: versionDiffer
                                            ? palette.warningAccent
                                            : palette.successAccent,
                                        emphasized: true,
                                      ),
                                    if (!hasRepo)
                                      _VersionChip(
                                        palette: palette,
                                        icon: Icons.link_off_rounded,
                                        label: '无法反推仓库',
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                  ],
                                ),
                                if (repoUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    repoUrl,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                      color: palette.bodyText.withValues(
                                        alpha: palette.isDark ? 0.82 : 0.78,
                                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({
    required this.palette,
    required this.selected,
  });

  final DashboardPaletteData palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? palette.primary
              : palette.mutedText.withValues(alpha: 0.35),
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? Icon(
              CupertinoIcons.checkmark_alt,
              size: 13,
              color: palette.inverseText,
            )
          : null,
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final DashboardPaletteData palette;
  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: palette.isDark
              ? (emphasized ? 0.22 : 0.16)
              : (emphasized ? 0.14 : 0.10),
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.36 : 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackupDialog extends StatelessWidget {
  const _DeleteBackupDialog({required this.item});

  final PluginBackupListItem item;

  String get _timeLabel =>
      '${item.createdAt.year.toString().padLeft(4, '0')}-'
      '${item.createdAt.month.toString().padLeft(2, '0')}-'
      '${item.createdAt.day.toString().padLeft(2, '0')} '
      '${item.createdAt.hour.toString().padLeft(2, '0')}:'
      '${item.createdAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPalette.of(context);
    final danger = Theme.of(context).colorScheme.error;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: palette.tileBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: palette.isDark ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: danger.withValues(alpha: palette.isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: danger.withValues(alpha: palette.isDark ? 0.4 : 0.28),
                ),
              ),
              child: Icon(
                CupertinoIcons.trash_fill,
                size: 24,
                color: danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '删除备份',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: palette.titleText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '删除后无法恢复，确定继续？',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: palette.bodyText.withValues(
                  alpha: palette.isDark ? 0.78 : 0.72,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: palette.surfaceAlt.withValues(
                  alpha: palette.isDark ? 0.55 : 0.85,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.tileBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.35,
                      color: palette.titleText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_timeLabel · ${item.pluginCount} 个插件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.bodyText.withValues(
                        alpha: palette.isDark ? 0.72 : 0.68,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: palette.surfaceAlt.withValues(
                      alpha: palette.isDark ? 0.55 : 0.9,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Get.back(result: false),
                      child: SizedBox(
                        height: 46,
                        child: Center(
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.titleText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: danger,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Get.back(result: true),
                      child: const SizedBox(
                        height: 46,
                        child: Center(
                          child: Text(
                            '删除',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
