# OmniHub 架构改造与安全加固同步说明（供 workbuddy 协同参考）

## 一、 核心背景与治理目标

为彻底消除开源仓库的敏感凭据泄露风险，并保障应用分发与二次开发时的安全规范与开箱即用体验，本次改动全面落实了**方案 A（编译期环境变量动态注入）**：
1. **凭据零硬编码**：源码中彻底移除所有明文个人凭据（115 Cookie、GitHub 访问 Token 等）。
2. **流水线安全注入**：通过 GitHub Actions 环境变量在编译打包期动态注入，与 GitHub 仓库后台 Secrets（私密变量）深度绑定。
3. **本地安全防线**：完善 Git 忽略规则、本地环境变量模板及本地打包辅助工具。
4. **协同规范沉淀**：建立系统性二开与协作指南文档，明确安全与协同红线。

---

## 二、 具体改动清单与技术细节

### 1. 业务凭据脱敏与动态读取
- **115 转存服务模块**：`lib/modules/dian115/services/pan115_service.dart`
  - 移除了此前源码中明文写死的个人 115 账号 Cookie。
  - 改为在编译期通过 `String.fromEnvironment('PAN115_COOKIE')` 动态读取。
  - 若未在编译期注入环境变量，则默认为空字符串，客户端将安全回退至读取本地持久化存储中的用户自定义配置，不破坏独立使用体验。
- **流水线状态查询模块**：`lib/modules/settings/services/github_actions_service.dart`
  - 移除了此前通过字符混淆写死在代码中的 GitHub 个人访问 Token。
  - 改为在编译期通过 `String.fromEnvironment('GITHUB_ACTIONS_TOKEN')` 动态读取。
  - 若未注入 Token，自动平滑降级走 GitHub 官方匿名接口，保证基础查询逻辑正常工作。

### 2. 云端 CI/CD 构建流水线适配（方案 A 落地）
- **iOS 业务热更新补丁流水线**：`.github/workflows/shorebird-patch.yml`
  - 在 Shorebird Patch 打包命令中追加 `--dart-define` 编译参数。
  - 关联 GitHub Secrets 动态读取 `PAN115_COOKIE` 与 `ACTIONS_TOKEN`。
- **iOS 底包发版流水线**：`.github/workflows/shorebird-release.yml`
  - 在 Shorebird Release 打包命令中追加环境变量编译参数。
- **Android 发版与跨平台编译流水线**：`.github/workflows/build-release.yml`
  - 在 Android 通用架构 APK、Android arm64 单架构 APK 以及 iOS 发版构建命令中，全量接入环境变量编译参数。
- **Secrets 命名兼容策略**：
  - 流水线中统一优先捕获 `secrets.ACTIONS_TOKEN` 与 `secrets.PAN115_COOKIE`，同时向下回退兼容 `secrets.GITHUB_ACTIONS_TOKEN`，杜绝因变量名细微差异导致注入失败。

### 3. 本地工程安全与脚手架规范
- **版本控制忽略加固**：`.gitignore`
  - 补充了对 `.env`、`.env.*`（排除 `.env.example`）、签名证书（`*.keystore`、`*.jks`、`key.properties`）、iOS 证书（`*.p12`、`*.mobileprovision`）的全局忽略规则。
- **环境模板**：`.env.example`
  - 新增本地开发所需的变量模板，详细罗列各变量作用与配置安全须知。
- **本地打包脚本**：`scripts/build_local.ps1`
  - 编写了跨平台 PowerShell 辅助脚本，支持本地开发调试时自动解析 `.env` 并注入打包参数。
- **全量开发与二开指南**：`CODEX_GUIDE.md`
  - 包含 500+ 行系统性指引：项目模块架构、自研功能保护清单、与官方上游仓库的代码合流同步规范、热更新发布与回滚机制、以及多 Agent 协同铁律。

---

## 三、 给 workbuddy 的后续开发协同与避坑指南

### 1. 凭据与安全红线（最高优先级）
- **严禁重新硬编码**：后续新增或调整任何接口、服务（如 115、阿里云盘、OpenAI、GitHub 等）时，绝对不可在 Dart 源码中硬编码明文凭据或 Token。
- **环境变量注入模式**：全局默认值统一采用 `String.fromEnvironment` 模式，并在变量为空时设计合理的降级与本地持久化读取逻辑。

### 2. JAV 模块安全铁律
- **杜绝静态敏感资源**：严禁向仓库提交任何涉黄、成人封面、截图或多媒体文件。
- **数据流与解析**：仓库仅保留通信协议、解析模型和通用 UI 组件，所有敏感资源均在客户端运行时通过私有服务动态拉取与渲染。

### 3. 代码生成防覆盖注意点
- **FormBlockModels 兼容问题**：`form_block_models.freezed.dart` 存在已知的重复类名冲突（`InfoCardRowMenu` 在 `menu` 与 `group` 构造器中同名），当前提交已做特殊修复。**请勿直接执行覆盖性的全量代码生成**（如 `build_runner build`），以免覆盖导致构建报错。

### 4. 当前 Git 分支与推送状态
- 本地与远端分支：`master` 分支（对应远端 `origin/master`）。
- 最新提交哈希：`671e07f`（`chore(security): sanitize secrets from codebase, inject via CI, and add developer guide`）。
- 云端构建状态：已触发 GitHub Actions 热更新流水线（Shorebird Patch），正在云端自动构建与分发补丁。
