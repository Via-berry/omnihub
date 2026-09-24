import 'package:flutter_test/flutter_test.dart';
import 'package:moviepilot_mobile/modules/search/models/app_update_info.dart';

void main() {
  group('AppUpdateInfo & ParsedReleaseVersion Tests', () {
    test('ParsedReleaseVersion from standard tag strings', () {
      final v1 = ParsedReleaseVersion.fromText('release-v1.2.7-2026-09-24');
      expect(v1.version, '1.2.7');
      expect(v1.buildNumber, isNull);

      final v2 = ParsedReleaseVersion.fromText('v1.2.8+39');
      expect(v2.version, '1.2.8');
      expect(v2.buildNumber, 39);

      final v3 = ParsedReleaseVersion.fromText('MoviePilotLite-Base-v1.2.7.ipa');
      expect(v3.version, '1.2.7');
      expect(v3.buildNumber, isNull);

      final v4 = ParsedReleaseVersion.fromText('ios-v1.2.7-2026-09-24.ipa');
      expect(v4.version, '1.2.7');
      expect(v4.buildNumber, isNull);
    });

    test('isNewer returns false when current version equals latest version', () {
      const info = AppUpdateInfo(
        currentVersion: '1.2.7',
        currentBuildNumber: 38,
        latestVersion: '1.2.7',
        latestBuildNumber: null,
        tagName: 'release-v1.2.7-2026-09-24',
        releaseName: 'v1.2.7-2026-09-24',
        releaseUrl: 'https://github.com/Via-berry/omnihub/releases/tag/release-v1.2.7-2026-09-24',
        releaseNotes: 'Release notes',
        apkDownloadUrl: 'https://github.com/Via-berry/omnihub/releases/download/release-v1.2.7-2026-09-24/ios-v1.2.7-2026-09-24.ipa',
        apkAssetName: 'ios-v1.2.7-2026-09-24.ipa',
        apkSize: 36577228,
      );

      expect(info.isNewer, isFalse);
    });

    test('isNewer returns true when newer semantic version is available', () {
      const info = AppUpdateInfo(
        currentVersion: '1.2.7',
        currentBuildNumber: 38,
        latestVersion: '1.2.8',
        latestBuildNumber: null,
        tagName: 'release-v1.2.8-2026-09-25',
        releaseName: 'v1.2.8',
        releaseUrl: 'https://github.com/Via-berry/omnihub/releases',
        releaseNotes: 'New feature',
        apkDownloadUrl: '',
        apkAssetName: '',
        apkSize: null,
      );

      expect(info.isNewer, isTrue);
    });

    test('isNewer compares build numbers when versions match', () {
      const infoSameBuild = AppUpdateInfo(
        currentVersion: '1.2.7',
        currentBuildNumber: 38,
        latestVersion: '1.2.7',
        latestBuildNumber: 38,
        tagName: 'v1.2.7+38',
        releaseName: 'v1.2.7+38',
        releaseUrl: '',
        releaseNotes: '',
        apkDownloadUrl: '',
        apkAssetName: '',
        apkSize: null,
      );
      expect(infoSameBuild.isNewer, isFalse);

      const infoHigherBuild = AppUpdateInfo(
        currentVersion: '1.2.7',
        currentBuildNumber: 38,
        latestVersion: '1.2.7',
        latestBuildNumber: 39,
        tagName: 'v1.2.7+39',
        releaseName: 'v1.2.7+39',
        releaseUrl: '',
        releaseNotes: '',
        apkDownloadUrl: '',
        apkAssetName: '',
        apkSize: null,
      );
      expect(infoHigherBuild.isNewer, isTrue);
    });
  });
}
