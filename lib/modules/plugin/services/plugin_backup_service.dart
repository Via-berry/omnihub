import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moviepilot_mobile/modules/plugin/models/plugin_backup_models.dart';
import 'package:moviepilot_mobile/modules/plugin/models/plugin_models.dart';
import 'package:path_provider/path_provider.dart';

class PluginBackupService {
  static const _rootDirName = 'plugin_backups';

  Future<Directory> _scopeDir(String scopeKey) async {
    final support = await getApplicationSupportDirectory();
    final safeScope = _sanitizeScope(scopeKey);
    final dir = Directory('${support.path}/$_rootDirName/$safeScope');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitizeScope(String scopeKey) {
    final trimmed = scopeKey.trim();
    if (trimmed.isEmpty) return '_default';
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  Future<PluginBackupFile> saveBackup({
    required String scopeKey,
    required List<PluginItem> plugins,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 暂不支持插件备份');
    }
    final backup = PluginBackupFile(
      version: PluginBackupFile.currentVersion,
      createdAt: DateTime.now(),
      scopeKey: scopeKey,
      plugins: plugins,
    );
    final dir = await _scopeDir(scopeKey);
    final stamp = _formatStamp(backup.createdAt);
    final fileName = 'plugins_$stamp.json';
    final file = File('${dir.path}/$fileName');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(backup.toJson()), flush: true);
    return PluginBackupFile(
      version: backup.version,
      createdAt: backup.createdAt,
      scopeKey: backup.scopeKey,
      plugins: backup.plugins,
      fileName: fileName,
      filePath: file.path,
    );
  }

  Future<List<PluginBackupListItem>> listBackups(String scopeKey) async {
    if (kIsWeb) return const [];
    final dir = await _scopeDir(scopeKey);
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
    final items = <PluginBackupListItem>[];
    for (final file in files) {
      try {
        final backup = await readBackupFile(file.path);
        items.add(
          PluginBackupListItem(
            fileName: backup.fileName.isNotEmpty
                ? backup.fileName
                : file.uri.pathSegments.last,
            filePath: file.path,
            createdAt: backup.createdAt,
            pluginCount: backup.plugins.length,
          ),
        );
      } catch (_) {
        final stat = await file.stat();
        items.add(
          PluginBackupListItem(
            fileName: file.uri.pathSegments.last,
            filePath: file.path,
            createdAt: stat.modified,
            pluginCount: 0,
          ),
        );
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<PluginBackupFile> readBackupFile(String path) async {
    final file = File(path);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式无效');
    }
    return PluginBackupFile.fromJson(
      Map<String, dynamic>.from(decoded),
      fileName: file.uri.pathSegments.isEmpty
          ? file.path
          : file.uri.pathSegments.last,
      filePath: file.path,
    );
  }

  Future<PluginBackupFile> readBackupBytes(
    List<int> bytes, {
    String fileName = '',
  }) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('备份文件格式无效');
    }
    return PluginBackupFile.fromJson(
      Map<String, dynamic>.from(decoded),
      fileName: fileName,
    );
  }

  Future<void> deleteBackup(String path) async {
    if (kIsWeb) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _formatStamp(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
