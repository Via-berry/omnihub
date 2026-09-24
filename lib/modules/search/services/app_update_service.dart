import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/applog/app_log.dart';
import 'package:moviepilot_mobile/modules/search/models/app_update_info.dart';
import 'package:moviepilot_mobile/modules/search/models/upstream_sync_info.dart';
import 'package:moviepilot_mobile/modules/settings/models/system_env_model.dart';
import 'package:moviepilot_mobile/services/api_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class AppUpdateService extends GetxService {
  AppUpdateService() : _dio = Dio(_baseOptions);

  final ShorebirdUpdater _shorebirdUpdater = ShorebirdUpdater();
  final Rx<int?> currentPatchNumber = Rx<int?>(null);

  bool get isShorebirdAvailable => _shorebirdUpdater.isAvailable;

  Future<void> initShorebird() async {
    if (!_shorebirdUpdater.isAvailable) return;
    try {
      final patch = await _shorebirdUpdater.readCurrentPatch();
      currentPatchNumber.value = patch?.number;
      _log.info('Shorebird 当前补丁: ${patch?.number ?? 'Base底包'}');

      _shorebirdUpdater.checkForUpdate().then((status) {
        if (status == UpdateStatus.outdated) {
          _log.info('发现新版 Shorebird 热补丁，正在后台自动拉取...');
          _shorebirdUpdater.update().then((_) {
            _log.info('Shorebird 热补丁下载完成，下次启动应用即可生效');
          }).catchError((e) {
            _log.warning('Shorebird 补丁下载失败: $e');
          });
        }
      }).catchError((e) {
        _log.warning('Shorebird 检查补丁失败: $e');
      });
    } catch (e) {
      _log.warning('初始化 Shorebird 失败: $e');
    }
  }

  Future<int?> loadPatchNumber() async {
    if (!_shorebirdUpdater.isAvailable) return null;
    try {
      final patch = await _shorebirdUpdater.readCurrentPatch();
      currentPatchNumber.value = patch?.number;
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  Future<UpdateStatus> checkShorebirdUpdate() async {
    if (!_shorebirdUpdater.isAvailable) return UpdateStatus.unavailable;
    return await _shorebirdUpdater.checkForUpdate();
  }

  Future<void> downloadShorebirdUpdate() async {
    if (!_shorebirdUpdater.isAvailable) return;
    await _shorebirdUpdater.update();
  }

  static const String owner = 'Via-berry';
  static const String repo = 'omnihub';
  static const String releasesUrl = 'https://github.com/$owner/$repo/releases';
  static const Duration cachedApkTtl = Duration(days: 7);
  static const String downloadProxyUrl = 'https://ghproxy.net/';

  static const String _defaultToken = String.fromEnvironment(
    'GITHUB_ACTIONS_TOKEN',
    defaultValue: '',
  );

  static List<String> _releaseApiUrls(String targetOwner, String targetRepo) => [
    'https://api.github.com/repos/$targetOwner/$targetRepo/releases',
    'https://gh-proxy.com/https://api.github.com/repos/$targetOwner/$targetRepo/releases',
    'https://gh.llkk.cc/https://api.github.com/repos/$targetOwner/$targetRepo/releases',
  ];

  static final BaseOptions _baseOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(seconds: 30),
    followRedirects: true,
    maxRedirects: 5,
    headers: const {
      'accept': 'application/vnd.github+json',
      'user-agent': 'OmniHub-Mobile-App',
    },
    validateStatus: (status) => status != null && status < 500,
  );

  final Dio _dio;
  final _log = Get.find<AppLog>();
  final _apiClient = Get.find<ApiClient>();

  Future<String?> _resolveGithubToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customToken = prefs.getString('custom_github_actions_token')?.trim();
      if (customToken != null && customToken.isNotEmpty) return customToken;
    } catch (_) {}

    if (_defaultToken.isNotEmpty) {
      return _defaultToken;
    }

    return await _loadConfiguredGithubToken();
  }

  Future<List<dynamic>> _fetchReleasesWithFallback({
    String targetOwner = owner,
    String targetRepo = repo,
    int perPage = 30,
  }) async {
    final token = await _resolveGithubToken();
    final headers = {
      'accept': 'application/vnd.github+json',
      'user-agent': 'OmniHub-Mobile-App',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
    final urls = _releaseApiUrls(targetOwner, targetRepo);

    dynamic lastError;
    for (final url in urls) {
      try {
        final response = await _dio.get<dynamic>(
          url,
          queryParameters: {'per_page': perPage},
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );
        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 300) {
          if (response.data is List) {
            return response.data as List<dynamic>;
          }
        }
        if (status == 403 && _isRateLimited(response.data)) {
          _log.warning('GitHub 接口 [$url] 限流，切换备用线路');
          continue;
        }
      } catch (e) {
        lastError = e;
        _log.warning('请求 GitHub 发布列表 [$url] 失败: $e，切换备用线路');
      }
    }

    if (token == null &&
        lastError != null &&
        lastError.toString().contains('403')) {
      throw AppUpdateException('GitHub API 已限流，请在设置中配置 Github Token 或稍后重试');
    }
    throw AppUpdateException('连接版本服务器失败，请检查网络设置');
  }

  Future<AppUpdateInfo> fetchLatestRelease() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber);

    final releases = await _fetchReleasesWithFallback(
      targetOwner: owner,
      targetRepo: repo,
      perPage: 30,
    );

    final data = _selectLatestRelease(releases);
    if (data == null) {
      throw AppUpdateException('暂无已发布的版本信息');
    }

    final assets = data['assets'];
    final asset = assets is List
        ? _selectPlatformAsset(assets.whereType<Map>().toList())
        : null;

    final tagName = _stringValue(data['tag_name']);
    final releaseName = _stringValue(data['name']);
    final versionSource = [
      tagName,
      releaseName,
      _stringValue(asset?['name']),
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '0.0.0');
    final latestVersion = ParsedReleaseVersion.fromText(versionSource);

    return AppUpdateInfo(
      currentVersion: packageInfo.version,
      currentBuildNumber: currentBuild,
      latestVersion: latestVersion.version,
      latestBuildNumber: latestVersion.buildNumber,
      tagName: tagName,
      releaseName: releaseName.isEmpty ? tagName : releaseName,
      releaseUrl: _stringValue(data['html_url'], fallback: releasesUrl),
      releaseNotes: _stringValue(data['body']),
      apkDownloadUrl: _stringValue(asset?['browser_download_url']),
      apkAssetName: _stringValue(asset?['name']),
      apkSize: _intValue(asset?['size']),
      publishedAt: DateTime.tryParse(_stringValue(data['published_at'])),
    );
  }

  Future<String> downloadApk(
    AppUpdateInfo info, {
    bool useProxy = false,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!info.hasApk) {
      throw AppUpdateException('未找到 APK 安装包');
    }
    final updateDir = await _updateCacheDirectory(create: true);
    final fileName = _safeFileName(
      info.apkAssetName.isEmpty
          ? 'MoviePilot-${info.latestLabel}.apk'
          : info.apkAssetName,
    );
    final file = File('${updateDir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
    try {
      await _dio.download(
        useProxy
            ? '$downloadProxyUrl${info.apkDownloadUrl}'
            : info.apkDownloadUrl,
        file.path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
          headers: const {'accept': 'application/octet-stream'},
        ),
      );
    } catch (_) {
      await _deleteFileIfExists(file);
      rethrow;
    }
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    if (!exists || size <= 0) {
      throw AppUpdateException('APK 下载失败');
    }
    _log.info('APK 下载完成: ${file.path}');
    return file.path;
  }

  Future<void> cleanupExpiredApkCache({Duration maxAge = cachedApkTtl}) async {
    try {
      final updateDir = await _updateCacheDirectory(create: false);
      if (!await updateDir.exists()) return;
      final now = DateTime.now();
      await for (final entity in updateDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last.toLowerCase();
        if (!name.endsWith('.apk')) continue;
        final stat = await entity.stat();
        if (maxAge == Duration.zero || now.difference(stat.modified) > maxAge) {
          await _deleteFileIfExists(entity);
        }
      }
    } catch (e) {
      _log.warning('清理过期 APK 缓存失败: $e');
    }
  }

  Map<dynamic, dynamic>? _selectPlatformAsset(
      List<Map<dynamic, dynamic>> assets) {
    if (assets.isEmpty) return null;
    if (Platform.isIOS) {
      final ipaAssets = assets.where((asset) {
        final name = _stringValue(asset['name']).toLowerCase();
        return name.endsWith('.ipa');
      }).toList();
      if (ipaAssets.isNotEmpty) {
        ipaAssets.sort((a, b) => _assetScore(b).compareTo(_assetScore(a)));
        return ipaAssets.first;
      }
    } else {
      final apkAssets = assets.where((asset) {
        final name = _stringValue(asset['name']).toLowerCase();
        return name.endsWith('.apk');
      }).toList();
      if (apkAssets.isNotEmpty) {
        apkAssets.sort((a, b) => _assetScore(b).compareTo(_assetScore(a)));
        return apkAssets.first;
      }
    }
    for (final asset in assets) {
      final name = _stringValue(asset['name']).toLowerCase();
      if (!name.endsWith('.sha256') &&
          !name.endsWith('.md5') &&
          !name.endsWith('.txt')) {
        return asset;
      }
    }
    return null;
  }

  Map<dynamic, dynamic>? _selectLatestRelease(List<dynamic> releases) {
    final candidates = releases.whereType<Map>().where((release) {
      if (release['draft'] == true) return false;
      final tagName = _stringValue(release['tag_name']);
      if (tagName.toLowerCase() == 'base-ios-latest') return false;
      return true;
    }).toList();
    if (candidates.isEmpty) {
      final validMaps = releases.whereType<Map>();
      return validMaps.isEmpty ? null : validMaps.first;
    }
    candidates.sort((a, b) {
      final left = DateTime.tryParse(_stringValue(a['published_at']));
      final right = DateTime.tryParse(_stringValue(b['published_at']));
      if (left != null && right != null) return right.compareTo(left);
      if (left != null) return -1;
      if (right != null) return 1;
      return _stringValue(b['tag_name']).compareTo(_stringValue(a['tag_name']));
    });
    return candidates.first;
  }

  int _assetScore(Map<dynamic, dynamic> asset) {
    final name = _stringValue(asset['name']).toLowerCase();
    var score = 0;
    if (name.contains('universal')) score += 8;
    if (name.contains('base')) score += 6;
    if (name.contains('release') ||
        name.contains('ios') ||
        name.contains('android')) {
      score += 4;
    }
    if (name.contains('arm64')) score += 2;
    if (name.contains('debug')) score -= 8;
    return score;
  }

  String _safeFileName(String value) {
    final trimmed = value.trim();
    final name = trimmed.isEmpty ? 'MoviePilot.apk' : trimmed;
    return name.replaceAll(RegExp(r'[^\w.\-()+]'), '_');
  }

  Future<Directory> _updateCacheDirectory({required bool create}) async {
    final dir = await getTemporaryDirectory();
    final updateDir = Directory('${dir.path}/app_updates');
    if (create && !await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log.warning('删除 APK 缓存失败: $e');
    }
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<String?> _loadConfiguredGithubToken() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/system/env',
        skipUnauthorizedHandling: true,
      );
      final status = response.statusCode ?? 0;
      final body = response.data;
      if (status < 200 || status >= 300 || body == null) return null;
      final parsed = SystemEnvResponse.fromJson(body);
      final data = parsed.data;
      final token = data?.githubToken?.trim();
      if (token != null && token.isNotEmpty) return token;
      final repoToken = data?.repoGithubToken?.trim();
      return repoToken == null || repoToken.isEmpty ? null : repoToken;
    } catch (e) {
      _log.warning('读取 Github Token 失败: $e');
      return null;
    }
  }

  bool _isRateLimited(Object? data) {
    if (data is! Map) return false;
    final message = _stringValue(data['message']).toLowerCase();
    return message.contains('rate limit');
  }

  Future<UpstreamCheckResult> checkUpstreamSync(
    UpstreamBaselineInfo baseline,
  ) async {
    final parts = baseline.repo.split('/');
    final targetOwner = parts.isNotEmpty ? parts[0] : 'singleton-altman';
    final targetRepo = parts.length > 1 ? parts[1] : 'MoviePilotLite';

    final releases = await _fetchReleasesWithFallback(
      targetOwner: targetOwner,
      targetRepo: targetRepo,
      perPage: 10,
    );

    if (releases.isEmpty) {
      throw AppUpdateException('获取上游版本失败');
    }

    final latestRelease = releases.firstWhere(
      (item) => item is Map && item['prerelease'] != true,
      orElse: () => releases.first,
    );

    final tagName = _stringValue(latestRelease['tag_name']);
    final releaseName = _stringValue(latestRelease['name']);
    final notes = _stringValue(latestRelease['body']);
    final upstreamRepoUrl = 'https://github.com/${baseline.repo}/releases';
    final htmlUrl =
        _stringValue(latestRelease['html_url'], fallback: upstreamRepoUrl);
    final publishedStr = _stringValue(latestRelease['published_at']);
    final publishedAt = DateTime.tryParse(publishedStr);

    final hasUpdate =
        tagName.isNotEmpty && !_isSameTag(tagName, baseline.baselineTag);

    return UpstreamCheckResult(
      baseline: baseline,
      latestTag: tagName.isEmpty ? baseline.baselineTag : tagName,
      latestReleaseName: releaseName.isEmpty ? tagName : releaseName,
      latestNotes: notes,
      releaseUrl: htmlUrl,
      hasUpdate: hasUpdate,
      publishedAt: publishedAt,
    );
  }

  bool _isSameTag(String a, String b) {
    if (a.trim().toLowerCase() == b.trim().toLowerCase()) return true;
    final cleanA =
        a.replaceAll(RegExp(r'-\d{4}-\d{2}-\d{2}$'), '').trim().toLowerCase();
    final cleanB =
        b.replaceAll(RegExp(r'-\d{4}-\d{2}-\d{2}$'), '').trim().toLowerCase();
    return cleanA.isNotEmpty && cleanA == cleanB;
  }
}

class AppUpdateException implements Exception {
  AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
