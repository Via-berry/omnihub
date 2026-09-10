class UpstreamBaselineInfo {
  const UpstreamBaselineInfo({
    required this.repo,
    required this.baselineTag,
    required this.baselineCommit,
    required this.lastSyncedAt,
    this.features = const [],
  });

  final String repo;
  final String baselineTag;
  final String baselineCommit;
  final String lastSyncedAt;
  final List<String> features;

  factory UpstreamBaselineInfo.defaultBaseline() {
    return const UpstreamBaselineInfo(
      repo: "singleton-altman/MoviePilotLite",
      baselineTag: "release-v1.2.5-2026-09-07",
      baselineCommit: "b3ad117",
      lastSyncedAt: "2026-09-10",
      features: [
        "MoviePilot v3 接口认证与信封模型深度适配",
        "插件配置差异备份、对比与增量恢复",
        "探索页全新 AniList 动漫多维分类与筛选",
        "探索页过滤弹层重构与选择芯片优化",
        "演员头像高清解析与图片多级缓存增强",
        "搜索进度条精确控制与仪表盘内存展示优化",
      ],
    );
  }

  factory UpstreamBaselineInfo.fromJson(Map<String, dynamic> json) {
    return UpstreamBaselineInfo(
      repo: json["upstream_repo"]?.toString() ?? "singleton-altman/MoviePilotLite",
      baselineTag: json["baseline_tag"]?.toString() ?? "release-v1.2.5-2026-09-07",
      baselineCommit: json["baseline_commit"]?.toString() ?? "b3ad117",
      lastSyncedAt: json["last_synced_at"]?.toString() ?? "2026-09-10",
      features: (json["features"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String get shortSummary => "$baselineTag ($baselineCommit)";
}

class UpstreamCheckResult {
  const UpstreamCheckResult({
    required this.baseline,
    required this.latestTag,
    required this.latestReleaseName,
    required this.latestNotes,
    required this.releaseUrl,
    required this.hasUpdate,
    this.publishedAt,
  });

  final UpstreamBaselineInfo baseline;
  final String latestTag;
  final String latestReleaseName;
  final String latestNotes;
  final String releaseUrl;
  final bool hasUpdate;
  final DateTime? publishedAt;

  String get promptInstruction =>
      "上游 MoviePilotLite 发布了新版本 $latestTag。请帮我同步上游最新代码到 OmniHub，并保留自研模块（Dian115/JAV/热更配置）！";
}

