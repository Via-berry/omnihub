import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum OmniHubReleaseType {
  hotPatch,
  majorFeature,
  upstreamSync,
  bugFix,
}

extension OmniHubReleaseTypeExt on OmniHubReleaseType {
  String get label => switch (this) {
        OmniHubReleaseType.hotPatch => '热更新补丁',
        OmniHubReleaseType.majorFeature => '重要特性',
        OmniHubReleaseType.upstreamSync => '基线合并',
        OmniHubReleaseType.bugFix => '缺陷修复',
      };

  Color get color => switch (this) {
        OmniHubReleaseType.hotPatch => CupertinoColors.systemOrange,
        OmniHubReleaseType.majorFeature => CupertinoColors.activeBlue,
        OmniHubReleaseType.upstreamSync => CupertinoColors.systemPurple,
        OmniHubReleaseType.bugFix => CupertinoColors.systemGreen,
      };

  IconData get icon => switch (this) {
        OmniHubReleaseType.hotPatch => Icons.bolt_rounded,
        OmniHubReleaseType.majorFeature => Icons.stars_rounded,
        OmniHubReleaseType.upstreamSync => Icons.merge_type_rounded,
        OmniHubReleaseType.bugFix => Icons.build_circle_outlined,
      };
}

class OmniHubReleaseItem {
  final String id;
  final String version;
  final int? patchNumber;
  final String date;
  final String title;
  final OmniHubReleaseType type;
  final String summary;
  final List<String> tags;
  final List<String> highlights;

  const OmniHubReleaseItem({
    required this.id,
    required this.version,
    this.patchNumber,
    required this.date,
    required this.title,
    required this.type,
    required this.summary,
    required this.tags,
    required this.highlights,
  });

  String get displayTag =>
      patchNumber != null ? '补丁 #$patchNumber' : type.label;
}

class OmniHubReleaseHistory {
  static const List<OmniHubReleaseItem> releases = [
    OmniHubReleaseItem(
      id: 'omnihub-20260912-multitransfer',
      version: 'v1.2.5',
      date: '2026-09-12',
      title: '多链接资源全量批量转存 & JAV 私有密文缓存',
      type: OmniHubReleaseType.hotPatch,
      summary: '修复癫影与盘搜多分集批量转存遗漏，升级 JAV 本地封面私有加密与透明代理',
      tags: ['热更新', '批量转存', 'JAV加密', 'Dian115', 'PanSou'],
      highlights: [
        '解决癫影与盘搜多分集（多 ed2k / 磁力链接）转存仅保存首条的问题，现支持完整提取与批量保存',
        '网关与直连 115 离线任务接口全面适配批量任务队列，增加智能间隔防风控截断与已存在容错',
        '卡片与转存弹层新增多链接数量胶囊标识与保存提示，支持一键快捷复制全部离线下载链接',
        'JAV 封面缓存采用 OMNIPIC 魔数与 AES-256-CTR 磁盘密文存储，杜绝 NAS 共享目录明文裸露',
        '服务端内置透明流式解密代理与存量图片平滑清洗迁移，无缝兼容客户端既有图片加载体系',
      ],
    ),
    OmniHubReleaseItem(
      id: 'omnihub-20260911-pansou',
      version: 'v1.2.5',
      date: '2026-09-11',
      title: 'PanSou 聚合搜索与 115 官方快照动态测容',
      type: OmniHubReleaseType.hotPatch,
      summary: '新增 PanSou 115/磁力/电驴聚合检索与免登官方快照异步动态测容',
      tags: ['热更新', 'PanSou', '115测容', '磁力电驴', '基线对齐'],
      highlights: [
        '集成开源 PanSou 聚合搜索渠道，支持局域网与 Docker 容器服务无缝直连',
        '新增 115 网盘、磁力链接与电驴 (ed2k) 免解锁检索与一键转存至 115 网盘',
        '首创 115 官方免登快照异步测容机制：自动补充缺失大小并实时标明失效资源',
        '对齐上游 MoviePilotLite release-v1.2.5-2026-09-11 最新发布标签与基线规范',
        '重构应用设置版本展示架构，建立 OmniHub 专属发布与热更新日志中心',
      ],
    ),
    OmniHubReleaseItem(
      id: 'omnihub-20260910-dian115',
      version: 'v1.2.5',
      date: '2026-09-10',
      title: 'Dian115 原生鉴权修复与上游基线自动化同步',
      type: OmniHubReleaseType.hotPatch,
      summary: '修复 115 HttpOnly Cookie 授权、重构登录防卡死并引入长效同步 CI',
      tags: ['热更新', 'Dian115', '鉴权修复', 'CI同步'],
      highlights: [
        '通过原生 CookieManager 深度提取 HttpOnly 授权凭据，彻底解决 400 Bad Request',
        '重构移动端原生登录续期弹窗，增加超时熔断防卡死与自定义宿主机配置入口',
        '增加上游代码基线长效检测机制与自动化同步 CI 工作流',
        '修复系统环境变量类型转换导致页面异常的缺陷',
      ],
    ),
    OmniHubReleaseItem(
      id: 'omnihub-20260908-ci',
      version: 'v1.2.5',
      date: '2026-09-08',
      title: '热更新构建追踪与高可用镜像容灾',
      type: OmniHubReleaseType.majorFeature,
      summary: '设置页实时监控 GitHub Actions 构建状态，引入多节点镜像容灾',
      tags: ['功能新增', 'Shorebird', '容灾切换', '高配额Token'],
      highlights: [
        '应用设置页新增热更新构建进度追踪，实时展示 GitHub Actions 状态与各构建阶段耗时',
        '引入多线路并发容灾调度机制（官方源与国内高速镜像无缝切换），蜂窝网络秒级加载',
        '内置高配额安全 API 凭据与持久化磁盘缓存，规避 GitHub API 匿名限流与空白问题',
      ],
    ),
    OmniHubReleaseItem(
      id: 'omnihub-20260907-v3',
      version: 'v1.2.5',
      date: '2026-09-07',
      title: 'MoviePilot v1.2.5 官方基线合并与 v3 协议适配',
      type: OmniHubReleaseType.upstreamSync,
      summary: '合并上游 release-v1.2.5 官方代码，深度适配 v3 响应信封模型',
      tags: ['基线合并', 'v3适配', 'arm64支持'],
      highlights: [
        '全量合并上游 MoviePilotLite release-v1.2.5 (b3ad117) 官方代码基线',
        '官方发布正式 arm64-v8a 独立架构 APK 打包构建与代理更新下载支持',
        '深度适配 MoviePilot v3 统一响应信封（Envelope）与媒体身份参数契约',
        '增强插件配置差异备份、对比与增量恢复能力',
      ],
    ),
    OmniHubReleaseItem(
      id: 'omnihub-20260905-dianying',
      version: 'v1.2.4',
      date: '2026-09-05',
      title: 'Dian115 癫影 115 云盘双渠道搜索与秒级转存',
      type: OmniHubReleaseType.majorFeature,
      summary: '双渠道资源搜索，Turnstile 人机验证与 115 一键秒级转存',
      tags: ['核心自研', 'Dian115', '一键秒存', 'Cloudflare'],
      highlights: [
        '新增癫影 115 双渠道资源搜索，与 PT 搜索无缝自由切换',
        '集成 Cloudflare Turnstile 验证弹层与会话自动续期',
        '支持 115 目录智能预选与自由切换，实现一键秒级转存到网盘',
      ],
    ),
  ];

  static OmniHubReleaseItem get latest => releases.first;
}
