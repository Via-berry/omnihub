# OmniHub

OmniHub 是一款基于 [MoviePilot](https://github.com/jxxghp/MoviePilot) 生态演进的现代化多媒体移动端管理终端。在全面继承 MoviePilot 原版核心业务体验（智能发现、精准搜索、站点管理、下载监控、订阅管理等）的基础上，深度集成了 **Shorebird 代码热推送（Code Push）** 引擎，彻底解决了 iOS 自签用户频繁重新签名与重装应用的痛点。

---

## 核心特性

- **永久免签免装（Code Push）**：
  - iOS 客户端只需在初次使用时通过 **全能签**（或爱思助手、AltStore 等）完成一次 Base 底包的自签名安装；
  - 后续所有的 Dart 业务功能新增、UI 界面优化与 Bug 修复，均由云端差分补丁自动静默下发，打开 App 即可直接热更生效，无需再次签名与覆盖安装。
- **100% 还原原版生态**：
  - 完整保留原生精致的毛玻璃设计质感与操作手感；
  - 完美对接 MoviePilot v2 REST API，支持各类媒体服务器（Emby / Jellyfin / Plex）与下载器状态实时监控。
- **全自动化 CI/CD 云端流水线**：
  - 依托 GitHub Actions 云端构建，自动生成 Base 独立底包并在 Releases 发布；
  - 主分支代码提交自动触发 Shorebird Patch 补丁编译与全球 CDN 分发，实现极速迭代。

---

## 快速上手（iOS 用户）

### 首次安装（仅需一次）
1. 前往本仓库的 [Releases 页面](../../releases/tag/base-ios-latest)；
2. 下载最新的底包文件 `MoviePilotLite-Base-v1.2.3.ipa`；
3. 将该文件导入手机上的 **全能签**（或其他自签工具），使用你的自签证书签名并安装到 iPhone。

### 日常使用与热更新
- 首次安装并登录连接你的 MoviePilot 服务端即可正常使用；
- 当有新功能或代码变动发布时，无需执行任何下载安装动作，App 会在启动时自动拉取并应用最新补丁。

---

## 平台支持

| 平台 | 状态 | 说明 |
|:---|:---:|:---|
| **iOS** | 唯一发布目标 | 发布未签名 IPA（需 AltStore / Sideloadly / Xcode 自签安装），安装后通过 Shorebird 热更新 |
| **Android** | 不再发版 | 自 2026-09-24 起不再构建 APK（仓库未配签名 secrets，且无发布需求），仅保留本地调试能力 |
| **macOS** | 支持 | 桌面端调试与构建 |

> 分发模型：**iOS 底包 + Shorebird 热更新**。日常改动只打补丁；含原生插件或 Info.plist 的改动
> 必须重建底包 IPA（`flutter_secure_storage` 这类新插件无法通过补丁下发）。

---

## 开发与云端构建

### 本地环境
- Flutter 3.38.2 / Dart 3.10+
- iOS 调试工具链 / Android SDK
- 准备可连接的 MoviePilot 服务端（API 文档：[api.movie-pilot.org](https://api.movie-pilot.org)）

### 常用命令
```bash
# 获取依赖
flutter pub get

# 静态分析与测试
flutter analyze
flutter test
```

### GitHub Actions 流水线
- **Build Release（仅 iOS）**：手动或每周五定时触发，产出未签名 IPA + sha256 并发布 GitHub Release。
  自 2026-09-24 起已移除 Android 构建；如需恢复，先补配
  `ANDROID_KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` 四个 secrets，
  再恢复 `build-android` 作业（Gradle 已在无 secrets 时退化为 debug 签名）。
- **Shorebird Release（iOS Base 底包构建）**：手动触发，构建最新 iOS 底包并推送到 Shorebird。
- **Shorebird Patch（iOS 业务热更新）**：推送到 `master` 分支自动打补丁并推送至 Shorebird。
  仅监听 `master`（`main` 是上游原始代码，打出的补丁与底包不匹配）。
  提交信息含 `[skip ci]` 会跳过流水线，含原生改动、只发完整包时用。
- **upstream-sync**：对齐上游 MoviePilotLite 基线。

> ⚠️ `paths-ignore` 含 `**/*.md`，只改 md 的推送不会触发补丁。CHANGELOG.md 必须与代码改动
> 一起推送才会进设备。热更新前同时更新 `lib/modules/search/models/omnihub_release_log.dart`
> 与 `CHANGELOG.md`，应用设置页才看得到记录。

---

## 致谢与开源说明

- 感谢 [MoviePilot](https://github.com/jxxghp/MoviePilot) 提供的优秀开源媒体自动化服务；
- 感谢 [MoviePilotLite](https://github.com/singleton-altman/MoviePilotLite) 提供的移动端跨端客户端基础；
- 感谢 [Shorebird](https://shorebird.dev) 提供的 Flutter 动态代码热推送基础设施。
