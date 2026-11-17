# OmniHub 开发者完整指南（Codex 适用）

> **用途**：本文档是 OmniHub 项目的二开全量参考手册，供 Codex（或任何 AI 编程助手）在无任何历史上下文的情况下独立完成开发、构建与发布任务。

---

## 目录

1. [项目概述](#1-项目概述)
2. [仓库结构](#2-仓库结构)
3. [技术栈与依赖](#3-技术栈与依赖)
4. [开发环境](#4-开发环境)
5. [Secrets 与 API Key 清单](#5-secrets-与-api-key-清单)
6. [构建与发布流程](#6-构建与发布流程)
7. [Shorebird 热更新（iOS 热补丁）](#7-shorebird-热更新ios-热补丁)
8. [上游代码同步流程](#8-上游代码同步流程)
9. [核心自研模块](#9-核心自研模块)
10. [发布日志规范（OmniHubReleaseLog）](#10-发布日志规范omnihubreleaselog)
11. [JAV 模块安全规范](#11-jav-模块安全规范)
12. [Agent 编码公约](#12-agent-编码公约)
13. [常见操作 SOP](#13-常见操作-sop)

---

## 1. 项目概述

**OmniHub** 是基于开源项目 [MoviePilotLite](https://github.com/singleton-altman/MoviePilotLite) 的 Flutter 移动端二开版本，由 **Via-berry** 维护。

- **上游仓库**：`singleton-altman/MoviePilotLite`（公开 GitHub）
- **本仓库**：`Via-berry/omnihub`（**公开仓库**，Fork 性质）
- **Flutter 包名**：`moviepilot_mobile`（内部 Dart package name）
- **当前版本**：`1.2.5+36`（`pubspec.yaml` 中 `version` 字段）
- **目标平台**：Android / iOS / macOS（**无** web / linux）
- **API Server 文档**：https://api.movie-pilot.org（所有接口均以此 Swagger 为准）

> ### ⚠️ 公开仓库安全铁律（最高优先级）
>
> 本仓库为 **public**。以下内容一旦提交即视为**永久泄露**——git 历史可回溯，且可能已被搜索引擎、爬虫、AI 训练集收录：
>
> - ❌ 任何真实凭据：Token、Cookie、密码、API Key、私钥、签名文件（`.jks` / `.p12` / `key.properties`）
> - ❌ 未脱敏的内网拓扑：真实内网 IP / 端口（配置默认值请留空，示例一律用 `192.168.1.100` 之类通用地址）
> - ❌ 任何媒体资源（另见第 11 节 JAV 安全规范）
>
> **硬编码 + 混淆（XOR / Base64 / 字符码偏移）不构成任何保护**，还原成本近乎为零，等同明文。
> 需要随构建下发但不宜公开的值，一律走 `--dart-define` 构建期注入（见第 5 节）。
>
> 处置已泄露凭据的正确顺序：**① 先吊销（唯一能让值失效的动作）→ ② 清理代码 → ③ 再考虑重写 git 历史**。
> 只删代码不吊销 = 什么都没做。

---

## 2. 仓库结构

```
omnihub/
├─ lib/
│  ├─ main.dart                  # 应用入口 & GetX 路由/绑定全量注册
│  ├─ services/                  # 全局单例服务
│  │  ├─ api_client.dart         # MoviePilot 后端 HTTP 客户端（Dio）
│  │  ├─ app_service.dart        # 全局状态服务（主题、认证、缓存）
│  │  ├─ hive_service.dart       # Hive 本地数据库初始化与注册
│  │  ├─ jpush_service.dart      # 极光推送服务
│  │  └─ sse_client.dart         # SSE 长连接客户端
│  ├─ modules/                   # 功能模块（每个模块含 controllers/models/pages/widgets）
│  │  ├─ dian115/                # 🔒 自研：癫影 115 双渠道搜索与转存
│  │  ├─ jav/                    # 🔒 自研：JAV 番剧浏览（含加密缓存）
│  │  ├─ pansou/                 # 🔒 自研：PanSou 聚合盘搜
│  │  ├─ search/                 # 资源搜索（含 AppSettingController 版本/热更逻辑）
│  │  ├─ settings/               # 应用设置（GitHub Actions 状态、发布日志页）
│  │  ├─ setting/                # 旧版设置模块（兼容保留）
│  │  └─ [其他上游模块...]       # dashboard/discover/subscribe/plugin/...
│  ├─ models/                    # 共用数据模型
│  ├─ widgets/                   # 共用 Widget 组件
│  ├─ theme/                     # 主题配置
│  ├─ utils/                     # 工具函数
│  └─ gen/                       # flutter_gen 自动生成（勿手改）
├─ assets/                       # 静态资源（SVG/Lottie/图标）
├─ android/                      # Android 原生配置
├─ ios/                          # iOS 原生配置（含 Podfile）
├─ macos/                        # macOS 原生配置
├─ .github/
│  ├─ workflows/
│  │  ├─ build-release.yml       # 完整 APK+IPA 构建并发布 GitHub Release
│  │  ├─ shorebird-patch.yml     # 🔥 热补丁：主分支 push 自动触发 iOS Shorebird patch
│  │  ├─ shorebird-release.yml   # 底包构建：手动触发，生成 Shorebird 底包 IPA
│  │  └─ upstream-sync.yml       # 每日自动巡检上游新版本并创建 Issue 提醒
│  └─ actions/
│     └─ telegram-notify/        # Telegram 发版通知 Action
├─ scripts/
│  └─ sync_upstream.ps1          # 本地上游代码同步 PowerShell 工具
├─ shorebird.yaml                # Shorebird 应用配置（app_id: 4612c7b1-7f15-4f9e-ad42-88095a33e023）
├─ upstream_baseline.json        # 当前对齐的上游基线版本记录
├─ pubspec.yaml                  # Flutter 项目依赖声明
├─ CHANGELOG.md                  # 完整更新日志（人工维护）
└─ AGENTS.md                     # AI Agent 编码公约（最高优先级规则）
```

---

## 3. 技术栈与依赖

### 核心框架
| 依赖 | 用途 |
|------|------|
| `get ^4.7.2` | 状态管理、路由、依赖注入（GetX） |
| `dio ^5.7.0` | HTTP 客户端 |
| `hive_ce ^2.10.0` | 本地 KV 数据库 |
| `freezed_annotation ^2.4.4` | 不可变数据模型代码生成 |
| `shorebird_code_push ^2.0.7` | iOS 热补丁引擎（Shorebird） |
| `webview_flutter ^4.4.2` | WebView（Dian115 验证用） |

### 私有/本地依赖
| 包名 | 位置 | 说明 |
|------|------|------|
| `altman_downloader_control` | Git: `singleton-altman/altman_downloader_control` | 下载器控制原生组件 |
| `altman_totp` | `./altman_totp`（本地路径） | TOTP 验证工具 |
| `native_glass_navbar` | `./third_party/native_glass_navbar` | iOS 原生玻璃导航栏 |

### 代码生成（build_runner）
运行代码生成命令：
```bash
dart run build_runner build --delete-conflicting-outputs
```

> **注意**：`lib/modules/dynamic_form/models/form_block_models.freezed.dart` 存在已知的 `InfoCardRowMenu` 重复类问题，**不要重新生成此文件**，直接使用仓库提交版本。

---

## 4. 开发环境

### 云端 CI 环境（Codex / Cursor Cloud）
```
Flutter: 3.38.2  (at /opt/flutter)
Dart:    3.10.0  (bundled)
Android SDK: /opt/android-sdk  (SDK 36, build-tools 36.0.0, NDK 28.2)
ANDROID_HOME: /opt/android-sdk
PATH: 已在 ~/.bashrc 中配置
```

### 常用命令
```bash
# 安装依赖
flutter pub get

# 代码生成（freezed / json_serializable / flutter_gen）
dart run build_runner build --delete-conflicting-outputs

# 静态分析
flutter analyze

# 单元测试
flutter test

# 构建 Debug APK（CI 验证）
flutter build apk --debug

# 构建 Release APK（带环境变量）
flutter build apk --release --dart-define=FLUTTER_APP_ENV=release

# 构建 Release IPA（无签名，CI 用）
flutter build ios --release --no-codesign --dart-define=FLUTTER_APP_ENV=release
```

### 本地开发注意
- 首次 Android 构建会自动下载 Realm 原生二进制与 CMake，约需 2 分钟
- `pubspec.lock` 的微小版本漂移用 `git checkout -- pubspec.lock` 恢复
- 项目 **不支持** web 和 Linux 平台

---

## 5. Secrets 与 API Key 清单

所有 Secret 在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中配置。

### GitHub Actions Secrets

| Secret 名 | 用途 | 使用 Workflow |
|-----------|------|--------------|
| `SHOREBIRD_TOKEN` | Shorebird CLI 认证 Token | shorebird-patch.yml, shorebird-release.yml |
| `SHOREBIRD_KEY` | 备用别名（兼容旧配置）| shorebird-patch.yml |
| `ANDROID_KEYSTORE_BASE64` | Android 签名 Keystore（Base64 编码） | build-release.yml |
| `KEYSTORE_PASSWORD` | Keystore 密码 | build-release.yml |
| `KEY_ALIAS` | Keystore Key Alias | build-release.yml |
| `KEY_PASSWORD` | Key 密码 | build-release.yml |
| `TG_BOT_TOKEN` | Telegram Bot Token（发版通知） | build-release.yml |
| `TG_CHAT_ID` | Telegram 频道/群组 ID | build-release.yml |
| `GITHUB_TOKEN` | GitHub 自动提供，无需手动配置 | 所有 workflow |

### GitHub Token（客户端）—— 构建期注入，禁止硬编码

> **2026-09-21 变更**：此前 `lib/modules/settings/services/github_actions_service.dart` 内置了一枚
> XOR 混淆的高配额 GitHub Token。因仓库为 public，该 Token 已随源码公开，**该实现已被彻底移除**。
> 混淆不构成保护——XOR-42 逐字符可逆。

现行三层取值（优先级从高到低）：

1. **用户自定义**：设置页写入 `custom_github_actions_token`（存 SharedPreferences）
2. **构建期注入**：`--dart-define=GITHUB_ACTIONS_TOKEN=...`；未注入时为空字符串
3. **降级**：为空则走 GitHub **匿名调用**（60 次/小时/IP，仅读公开仓库元数据）

对本 App「查看 CI 状态」的场景，第 3 层已够用。若确需更高配额，请使用 **fine-grained PAT**
且**仅授予** `Actions: Read` + `Contents: Read`——绝不要用 repo 全权限的 classic token（`ghp_` 开头）。

**严禁再以任何形式把 Token 硬编码回源码。**

### 环境变量（.env，仅本地开发）

参考 `.env.example`（需自行创建 `.env`）。`.env` 与 `.env.*` 已列入 `.gitignore`，**不会提交**。

```env
# AI 能力（App 内 agent 模块）
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=...
DEEPSEEK_API_KEY=...
GOOGLE_API_KEY=...

# GitHub Actions 状态查询（建议 fine-grained，仅 Actions:Read + Contents:Read）
GITHUB_ACTIONS_TOKEN=
```

**本地构建注入**：`pwsh scripts/build_local.ps1 -Target apk|ios`
脚本从 `.env` 读取并转为 `--dart-define`，只打印变量名、不打印值。

> ⚠️ `--dart-define` 的值会被编译进 APK/IPA，**可被逆向提取**。
> 它解决的是"不进 git、不被索引"，**不等于加密**。真正的秘密必须留在服务端。

### Shorebird 配置
```yaml
# shorebird.yaml
app_id: 4612c7b1-7f15-4f9e-ad42-88095a33e023
auto_update: true
```
此文件打包进 App assets，Shorebird SDK 在运行时读取用于识别应用身份。

---

## 6. 构建与发布流程

### 6.1 完整版本发布（APK + IPA）

**触发方式**：手动触发（`workflow_dispatch`）或每周五 UTC 0:00 定时触发。

**Workflow 文件**：`.github/workflows/build-release.yml`

**流程**：
```
prepare job（读取 pubspec.yaml 版本号，生成文件名/Tag/Release名）
       ↓
build-android job（ubuntu-latest）   +   build-ios job（macos-latest）
   ↓                                      ↓
   1. flutter pub get                    1. flutter pub get
   2. 验证 Android Keystore              2. pod install
   3. build 通用 APK                     3. build unsigned iOS (--no-codesign)
   4. build arm64-v8a APK               4. 打包为 .ipa
   5. 上传 artifacts                    5. 上传 artifacts
                         ↓
              release job（ubuntu-latest）
              - 下载所有 artifacts
              - 创建 GitHub Release（Tag: release-v{version}-{date}）
              - 上传 APK + IPA
              - Telegram 发版通知
```

**产物命名规则**：
- APK：`android-v{version}-{date}.apk`
- arm64 APK：`android-arm64-v8a-v{version}-{date}.apk`
- IPA：`ios-v{version}-{date}.ipa`
- Tag：`release-v{version}-{date}`

### 6.2 Android Keystore 配置
Keystore 文件以 Base64 存入 `ANDROID_KEYSTORE_BASE64` Secret。构建时解码到 `$RUNNER_TEMP/moviepilot.keystore`，并通过 `keytool` 验签后注入 Flutter 构建环境。

本地签名配置在 `android/app/build.gradle`（通过 `ANDROID_KEYSTORE_PATH` 等环境变量读取）。

---

## 7. Shorebird 热更新（iOS 热补丁）

OmniHub 的 iOS 版本使用 **Shorebird** 实现无需重新签名的代码热推送。

### 流程架构

```
底包 IPA（含 Shorebird 引擎）
  ↓ 用户用全能签等工具自签安装（一次性）
运行时自动检测 patch
  ↓
Shorebird CDN 下发 Dart 层代码补丁
  ↓
App 重启后生效（无需重装）
```

### 底包构建（首次 / 原生变更时）

**Workflow**：`.github/workflows/shorebird-release.yml`
**触发方式**：手动触发（`workflow_dispatch`）

关键命令：
```bash
shorebird release ios --no-codesign -- --dart-define=FLUTTER_APP_ENV=release
```

构建完成后打包为 IPA 并创建 GitHub Release（Tag: `base-ios-latest`）。

### 热补丁发布（日常代码更新）

**Workflow**：`.github/workflows/shorebird-patch.yml`
**触发方式**：向 `master`/`main` 分支 push（自动触发），或手动触发

**触发排除**（push 以下内容时不触发热更）：
- `**.md`
- `.gitignore`
- `docs/**`
- `.github/workflows/upstream-sync.yml`
- `upstream_baseline.json`

关键命令：
```bash
shorebird patch ios --no-codesign \
  --release-version=latest \
  --allow-native-diffs \
  --allow-asset-diffs \
  -- --dart-define=FLUTTER_APP_ENV=release
```

### 客户端热更逻辑

位置：`lib/modules/search/controllers/app_setting_controller.dart`（`AppSettingController`）

```
App 启动
  → checkUpdateSilently()
      → iOS + Shorebird 可用 → _updateService.loadPatchNumber()
      → 拉取 GitHub 最新 Release 信息（AppUpdateService）
  → 用户手动点击版本区域
      → checkForUpdate()
          → iOS: checkShorebirdUpdate() → 发现补丁 → 自动拉取并提示重启
          → Android: 显示 APK 下载对话框
```

相关服务：
- `lib/modules/search/services/app_update_service.dart` — 版本检测 + Shorebird 调用
- `lib/modules/search/services/app_update_installer.dart` — Android APK 安装

---

## 8. 上游代码同步流程

### 上游信息
- **上游仓库**：`singleton-altman/MoviePilotLite`
- **当前基线**：见 `upstream_baseline.json`

```json
{
  "upstream_repo": "singleton-altman/MoviePilotLite",
  "baseline_tag": "release-v1.2.5-2026-09-11",
  "baseline_commit": "b3ad117",
  "last_synced_at": "2026-09-11T19:40:00+08:00"
}
```

### 自动巡检（每日）

**Workflow**：`.github/workflows/upstream-sync.yml`
**触发**：每天北京时间 10:00（UTC 02:00）+ 手动触发

逻辑：
1. 读取 `upstream_baseline.json` 中的基线 Tag
2. 查询 `singleton-altman/MoviePilotLite` 最新 Release
3. 如有新版本且尚无对应 Issue → 自动创建 `[上游更新提醒]` Issue（含 AI 助手一键合并提示词）

### 本地手动同步

```powershell
# 巡检（仅查看差异，不合并）
powershell -ExecutionPolicy Bypass -File scripts\sync_upstream.ps1

# 执行合并
powershell -ExecutionPolicy Bypass -File scripts\sync_upstream.ps1 -Merge
```

脚本逻辑：
1. 自动添加 `upstream` remote（指向 MoviePilotLite）
2. `git fetch upstream --tags`
3. 展示当前 ahead/behind 提交数与文件差异
4. 检测自研敏感冲突区（`dian115 / jav / shorebird / app_setting` 相关文件）
5. `-Merge` 时执行 `git merge upstream/master`

### 合并后必做检查
1. 解决冲突（重点保护自研模块：`dian115 / jav / pansou / settings / search/controllers/app_setting_controller.dart`）
2. `flutter pub get`
3. `flutter analyze`
4. `flutter build apk --debug`（或通过 CI 验证）
5. 更新 `upstream_baseline.json` 的 `baseline_tag`, `baseline_commit`, `last_synced_at`
6. 更新 `CHANGELOG.md`

---

## 9. 核心自研模块

以下模块是 OmniHub 相对上游的自研差异，**合并上游时需特别保护**：

### 9.1 Dian115（癫影 115）

**位置**：`lib/modules/dian115/`

核心能力：
- 双渠道资源搜索（癫影网站 + PanSou）
- Cloudflare Turnstile 人机验证（WebView 注入 JS）
- HttpOnly Cookie 授权（原生 CookieManager 提取）
- 115 网盘一键秒级转存（支持多分集批量 ed2k/磁力链接）
- 资源卡片多链接标识 UI

关键文件：
- `services/dian115_service.dart` — API 调用层
- `widgets/dian115_share_card.dart` — 资源卡片（含多链接胶囊）
- `widgets/dian115_transfer_confirm_sheet.dart` — 转存确认弹层
- `widgets/dian115_verify_sheet.dart` — Cloudflare 验证 WebView

### 9.2 PanSou（盘搜）

**位置**：`lib/modules/pansou/`

核心能力：
- 聚合搜索局域网/Docker 部署的 PanSou 服务
- 支持 115 分享链接、磁力链接、ed2k 多链接资源
- 资源卡片多链接一键复制

### 9.3 JAV 模块

**位置**：`lib/modules/jav/`

核心能力：
- 番剧信息浏览（对接私有内网服务）
- **脱敏避人模式**（`JavSafeService`）：默认开启，封面模糊，长按临时透视
- **AES-256-CTR 磁盘加密**：NAS 服务端封面缓存以 `OMNIPIC` 魔数头 + 密文存储，客户端通过解密代理无感加载

关键文件：
- `services/jav_api_service.dart` — API 客户端
- `services/jav_safe_service.dart` — 脱敏模式状态管理

> **安全铁律**：严禁向仓库提交任何图片/视频等媒体资源，所有媒体均运行时从私有内网拉取。

### 9.4 应用设置（AppSetting）

**位置**：`lib/modules/search/controllers/app_setting_controller.dart`

核心能力：
- **版本检测**：检查 GitHub Release 是否有新版本，展示 APK 下载进度
- **Shorebird 热补丁**：iOS 下自动检测并拉取热补丁，展示当前补丁号
- **OmniHub 发布日志**：展示自研发布历史（见第 10 节）
- **GitHub Actions 状态**：拉取最新 Workflow 运行状态展示构建进度
- **上游基线检测**：展示当前对齐的上游版本
- **主题/背景图/应用图标**：主题色、背景图、8 套应用图标切换

### 9.5 GitHub Actions 服务

**位置**：`lib/modules/settings/services/github_actions_service.dart`

核心能力：
- 目标仓库：`Via-berry/omnihub`
- 多节点容灾：官方 API → `gh-proxy.com` → `gh.llkk.cc` 自动降级
- 内置混淆 Token（XOR 编码），支持用户自定义 Token 覆盖

---

## 10. 发布日志规范（OmniHubReleaseLog）

OmniHub 有独立的发布日志体系，**不依赖** GitHub Release，而是内嵌于 App 代码中展示。

**数据文件**：`lib/modules/search/models/omnihub_release_log.dart`

### 发布类型（OmniHubReleaseType）

| 枚举值 | 标签 | 场景 |
|--------|------|------|
| `hotPatch` | 热更新补丁 | 通过 Shorebird 推送的补丁 |
| `majorFeature` | 重要特性 | 大型新功能 |
| `upstreamSync` | 基线合并 | 对齐上游新版本 |
| `bugFix` | 缺陷修复 | 专项 Bug 修复 |

### 新增发布记录 SOP

每次发版（热更新或常规更新）后，在 `OmniHubReleaseHistory.releases` 列表**头部**插入新条目：

```dart
OmniHubReleaseItem(
  id: 'omnihub-{YYYYMMDD}-{slug}',   // 唯一 ID，格式固定
  version: 'v1.2.5',
  patchNumber: null,                  // 热补丁编号（可选）
  date: '2026-09-18',
  title: '功能标题',
  type: OmniHubReleaseType.hotPatch,
  summary: '一句话摘要',
  tags: ['热更新', '功能关键词'],
  highlights: [
    '第一条变更说明',
    '第二条变更说明',
  ],
),
```

同步更新 `CHANGELOG.md`（在文件顶部插入新版本节）。

---

## 11. JAV 模块安全规范

以下为强制性安全规则：

1. **严禁提交任何媒体文件**（图片、封面、视频、GIF）到 Git 仓库。
2. 仓库内只允许保留：业务逻辑代码、API 客户端、数据模型、UI 组件。
3. 所有封面图片通过私有内网服务运行时动态拉取，不得打包为静态资源。
4. NAS 服务端封面缓存必须使用 AES-256-CTR 加密存储（`OMNIPIC` 魔数头）。
5. 客户端统一通过服务端透明解密代理接口加载图片，不直接读取磁盘密文。

---

## 12. Agent 编码公约

（来源：`AGENTS.md`，最高优先级，任何操作均不得违反）

### Flutter 页面结构
- 页面根布局用 `Scaffold`，顶栏用 `appBar`（`AppBar` 或实现 `PreferredSizeWidget` 的组件）。
- 新增页面**不使用** `CupertinoPageScaffold` 作为整页根。

### API 约定
- 所有 HTTP 请求严格按照 https://api.movie-pilot.org Swagger 文档执行，接口路径、方法、参数、请求体、Header、鉴权均以 Swagger 为准。

### 输出约束
- **禁止**在对话回复中输出代码内容（代码块、代码片段、patch/diff、内联代码等）。
- 代码修改**只允许直接改动仓库文件**，不展示代码。

---

## 13. 常见操作 SOP

### SOP-1：发一次 iOS 热更新补丁

1. 在 `master`/`main` 分支完成代码修改并 push
2. GitHub Actions 自动触发 `Shorebird Patch (iOS 业务热更新)` Workflow
3. 等待 Workflow 完成（约 15~30 分钟）
4. 在 `lib/modules/search/models/omnihub_release_log.dart` 头部追加新 `OmniHubReleaseItem`（`type: OmniHubReleaseType.hotPatch`）
5. 更新 `CHANGELOG.md` 顶部
6. 再次 push（此时会再触发一次热更新 Workflow，属正常）

### SOP-2：合并上游新版本

1. 运行 `scripts\sync_upstream.ps1`（巡检差异）
2. 确认无重大自研冲突后加 `-Merge` 参数执行合并
3. 解决冲突（重点：`dian115 / jav / pansou / app_setting_controller`）
4. `flutter pub get && flutter analyze && flutter build apk --debug`
5. 更新 `upstream_baseline.json`（`baseline_tag`, `baseline_commit`, `last_synced_at`）
6. 在 `OmniHubReleaseHistory` 头部追加 `type: OmniHubReleaseType.upstreamSync` 条目
7. 更新 `CHANGELOG.md`
8. push → 自动触发热更新 Workflow

### SOP-3：发完整 APK + IPA 版本包

1. 确保 `pubspec.yaml` 中 `version` 已更新（格式：`1.2.5+36`）
2. 在 GitHub Actions 手动触发 `Build Release` Workflow
3. 等待完成（约 20~40 分钟）
4. 检查 GitHub Releases 页面确认 APK + IPA 已上传
5. 检查 Telegram 通知是否发送成功

### SOP-4：构建 Shorebird 底包（首次或有原生变更时）

1. 手动触发 `.github/workflows/shorebird-release.yml`
2. 等待完成后，下载 `base-ios-latest` Release 中的 IPA
3. 用全能签/AltStore/牛蛙助手自签安装到 iPhone

### SOP-5：修改 OmniHub 自研功能

1. 确认改动涉及的文件（`dian115 / jav / pansou / settings / search`）
2. 遵守 JAV 模块安全铁律
3. 运行 `flutter analyze` 确认无 lint 错误
4. 运行 `flutter build apk --debug` 确认构建通过
5. push → 自动触发热更新

---

*文档生成时间：2026-09-18 · 维护方：Via-berry/OmniHub*
