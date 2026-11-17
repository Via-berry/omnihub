# jav 模块改为 MissAV 数据源

状态：调研完成，方案已定。后端第 0、1 步已实施并上线；第 2 步起未动。所有技术结论均来自实测（直连后端源码 + 直连 MissAV，走 NAS 代理出口 `192.168.50.81:63022`）。

方向：**MissAV 作主数据源直接替换 JavBus，不走融合。** JavBus 保留为兜底（磁链来源 + 覆盖回退）。

## 结论

可行。MissAV 详情页可直连抓取（200），且页面里直出 HLS 播放地址 —— 播放体验可以从 WebView 升级为原生播放器。

唯一硬骨头是**题材页与女优主页被 Cloudflare 403 挡死**，因此"分类浏览"改为自建题材索引实现（见「分类方案」），题材 id 与名称与 MissAV 同源，不是近似。

## 后端位置

不在本机仓库，在 NAS 的 SMB 共享里：

```
Y:\docker\omnihub\          FastAPI，docker-compose 映射 8923:8923
├─ server.py                317 行，全部路由 + 图片代理 + vault
├─ app/core/config.py       HOST / PORT / PROXIES（读 .env）
├─ app/core/cache.py        SQLite 缓存 omnihub_cache.db，get_cache/set_cache
├─ app/modules/jav/scraper.py    521 行 ← javbus 全部抓取逻辑
├─ app/modules/jav/alias.py      77 行 手写别名表
├─ app/modules/ai/agent.py       366 行 AI 找片
└─ .env                     HTTP_PROXY=http://192.168.50.81:63022
```

现有路由：`/api/jav/explore`、`/genres`、`/tags`、`/actresses`、`/search`、`/ai_search`、`/detail/{code}`、`/magnets`，另有 `/api/img/proxy`、`/api/ai/chat`、`/api/vault/verify`、`/health`。

客户端是本仓库 `lib/modules/jav/`（5904 行 Dart），纯 API 消费方，不含任何抓取逻辑。

## 现存 bug：MissAV 播放按钮一直是坏的

`scraper.py:437`：

```python
missav_url = f"https://missav.ai/{code.lower()}"
```

裸 code 路径实测返回 **403 Cloudflare 拦截页**。正确写法必须带 locale 后缀：

```python
missav_url = f"https://missav.ai/{code.lower()}/ja"
```

这是整个方案里性价比最高的一步，15 分钟改完，改完现有 App 的「MissAV 全网片源」线路立刻能用。建议单独发布，不等后续改造。

## MissAV 站点结构（实测）

**不是 WordPress**（`/wp-json` 404、`/graphql` 403）。自研 Vue + Alpine.js 的 SSR 站点。当前域名 `missav.ai`（`missav.co` 已转卖停放）。

### 详情页 `/<code>/{locale}` — 数据源主力

`ja` / `zh-tw` / `en` 三个 locale 实测均 200（约 220KB）。页面内容：

- `og:title` / `og:description` → 标题与剧情简介（`zh-tw` 为中文翻译）
- `og:image` → `fourhoi.com/{code}/cover-n.jpg`
- `og:video:release_date` → 发行日期
- 题材：`/dm{N}/genres/{tag}`，如 `/dm122/genres/單體作品`、`/dm156/genres/巨乳`、`/genres/VR`
- 女优 / 厂牌：`/dm13/actresses/九井スナオ`、`/dm88/makers/ROCKET`、`/dm190/labels/ROCKET`
- 内联字段：`dvd_id`、`has_chinese_subtitle`、`has_english_subtitle`
- **无 JSON-LD**，只能解析 HTML 与 meta
- 外部镜像源页：`/site/123av`、`/site/njav`、`/site/supjav`
- 广告脚本：`cdn.tsyndicate.com/sdk/v1/ms.js`、`myavlive.com`、`mayzaent.com`

### 播放地址 — PE-deflate 混淆，解开即用

页面内嵌一段 PE-deflate 混淆脚本：

```
eval(function(p,a,c,k,e,d){...}('e=\'8://7.6/5-4-3-2-1/d.0\';...',15,15,
'm3u8|ce41f44eb977|9788|41f6|d156|9a8a0702|com|surrit|https|video|720p|source1280|source842|playlist|source'.split('|'),0,{}))
```

base-36 索引替换，从最高索引往下降序替换即可解开：

```python
def pe_deflate(tpl: str, words: list[str]) -> str:
    out = tpl
    for i in range(len(words), 0, -1):
        out = re.sub(r"\b" + str(i) + r"\b", words[i - 1], out)
    return out
```

解出：

```
https://surrit.com/<uuid>/playlist.m3u8          → 200 application/vnd.apple.mpegurl
https://surrit.com/<uuid>/720p/video.m3u8        → 200，49KB 媒体播放列表
```

页面用 `hls.js 1.4.3` + `plyr 3.6.8`，标准 HLS。`720p` 对应变量名 `source842` / `source1280`（清晰度切换）。

GUID 是服务端生成的不透明 token，无法从 code 推导，必须每次现解、短 TTL 缓存。

**架构红线：不要把 HLS 流从 NAS 反代出去。** `surrit.com` 同样在 Cloudflare 后面且会限流 —— 同一 m3u8 URL 第一次 200，一分钟后重取变成 "Sorry, you have been blocked"。NAS 是固定 IP，会被重点关照。正确做法是 NAS 只解出 URL 回传给客户端，让手机直连 surrit 播放（用户家庭宽带出口，与 MissAV 网页版同处境）。

### 图片 CDN `fourhoi.com`

按 code 命名，实测：

```
fourhoi.com/{code}/cover-n.jpg   → 200 image/jpeg 188KB
fourhoi.com/{code}/cover-t.jpg   → 缩略图
fourhoi.com/{code}/preview.mp4   → 200 video/mp4
```

**必须走 `/api/img/proxy` 代理**，fourhoi 直连会挂防盗链。

### 首页推荐 — 走 Recombee，页面里没有数据

`/dm285/ja`（343KB）页面内**没有任何内联 dvd_id**，列表全部客户端异步拉取：

```js
window.recombeeClient.send(new recombee.RecommendItemSegmentsToUser(
    window.user_uuid, window.recommendedRows - 1,
    { scenario: isDesktop() ? 'desktop-home-segments' : 'mobile-home-segments', ... }))
// 另有 RecommendItemsToUser / RecommendNextItems，题材名取自 window.genreMap[id]
```

Recombee client key 公开在页面里，可直接调用。"首页推荐"与"热度排序"本质上是推荐引擎的接口，不是网页列表。

### 白名单例外：`/actresses/ranking`

`https://missav.ai/actresses/ranking` 实测 200 / 281KB。题材页和女优主页都被挡，唯独女优榜没挡，可直接作女优维度的热度源。

## 三个必须在代码里处理的坑

### 坑 1：SPA 软 404，不存在的番号返回 200

```
GET /rctd-763/ja            → 200  220KB  dvd_id: 'rctd-763'  ✅ 真页面
GET /zzzz-999/ja            → 200  144KB  dvd_id: 无          ⛔ 软404
GET /embm-054_2026-09-20/ja → 200  140KB  dvd_id: 无          ⛔ 软404
GET /embm-054/ja            → 200  227KB  dvd_id: 'embm-054'  ✅ 真页面
```

软 404 页面 `<title>` 是通用的 `MissAV | 免費高清AV在線看`。

**存在性判定必须用 `re.search(r"dvd_id: '([a-z0-9\-]+)'", html)`，绝不能看 HTTP 状态码**，否则覆盖率统计会虚高、软 404 页面会被当有效详情缓存。

### 坑 2：code 必须先归一化

javbus 无码/破解列表会把日期挂在 code 上（`EMBM-054_2026-09-20`），MissAV 不认这个形式（软 404），去掉后正常（`embm-054` → 6 个题材）。

现有后端只有 `code.strip().upper()`，客户端另有一个 `ssis834 → SSIS-834` 的归一化正则 —— 散落两处。归一化要提到后端做成单一函数，覆盖：去 `_YYYY-MM-DD` 后缀、小写、保留连字符、去 `_UNCENSORED-LEAK` 之类标记（MissAV 页面自身就有 `replace('-UNCENSORED-LEAK', ...)`）。

### 坑 3：有效详情页也会被 Cloudflare 间歇拦成挑战页

同一 URL `start-634/ja` 两次抓取，一次 221KB 带 7 个题材，一次是 5.5KB 的 CF challenge（同样过 200 判定，但无任何题材链接）。

**挑战页判定：HTML 含 `Just a moment` 或 `cf-browser-verification` 即视为挑战。** 必须带已握手的 `cf_clearance` cookie 重试，且**严禁把挑战页写进缓存** —— 否则该片目会永久变成空详情。

### 挑战页与 CF 403 的区分

`/<code>` 裸路径 403 是**结构性**的（加 `/ja` 即通），`/dm{N}/genres/` 403 是**规则性**的（加什么都不通，含 canonical 路径）。前者加后缀解决，后者不要做重试风暴。

## 分类方案

题材页 `/dm{N}/genres/{tag}`、女优页 `/dm{N}/actresses/{name}`、`/graphql`、`/categories/genres` 全部 403，无法直取。

采用**自建题材索引**：抓详情页时顺手收它的题材链接，落库成 `{genre_id, tag, count}` 索引表。

**分类与 MissAV 的一致性**：`dm{N}` 是 MissAV 自己的题材 id，`{tag}` 是它自己的题材名原文（繁体中文），不是我方翻译。索引就是 MissAV 的 taxonomy 本身，只是收集方式从"下载题材页"换成"从详情页反向聚合"。

**收敛速度**（14 个真番号抽样实测）：

```
RCTD-763 → 8 个题材   AGAV-182 → 9 个   SDDE-768 → 7 个
14 个页面共 36 个不重复题材 id，约 2.6 个新 id / 页面
```

MissAV 题材总数估 100-200，爬 100-300 个详情页即可覆盖绝大部分。建议首批用 JavBus 列表灌 500 个 code 预热，之后增量更新。

**count 语义**：等于"已抓过详情且带此题材的影片数"，只增不减、单调正确，但不等于原站真实总数。**UI 不显示精确计数，只显示按 count 降序的排序**，避免用户与原站对数字时觉得不准。

题材页唯一的额外价值是"看某题材下有哪些片"，由反向索引解决（`genre_id → [code]`），再用已缓存的详情补全展示字段。

热度排序走 Recombee 带 filter 调用（`window.genreMap` 里的题材 id 作 filter），失效时回退自建索引的自然序。

不采用 headless 浏览器过 CF：NAS 常驻 Chromium 300MB+ 内存、频繁失效、持续对抗成本，且越过 ToS 边界。

## 后端改造

### 新增 `app/modules/jav/missav_scraper.py`

沿用 `JavScraper` 结构（`requests.Session` + UA + `PROXIES` + `get_cache/set_cache`）：

```python
class MissAvScraper:
    BASE_URLS = [u for u in os.getenv("MISSAV_BASE_URLS", "https://missav.ai").split(",") if u]
    LOCALE    = os.getenv("MISSAV_LOCALE", "zh-tw")
    LOCALES   = ("zh-tw", "ja")

    def norm_code(self, code: str) -> str          # 去 _YYYY-MM-DD / 去标记 / 小写 / 保留连字符
    def detail(self, code: str) -> dict | None     # 抓 /{code}/{locale}，校验 dvd_id 后解析
    def home_segments(self) -> list[dict]           # Recombee
    def genre_index(self) -> list[dict]             # 读自建索引表
    def genre_items(self, genre_id: str) -> list[dict]  # 反向索引 + 详情补全
```

`detail()` 内部判定顺序：

```
归一化 code
  → 请求 /{code}/{locale}
  → HTML 含 "Just a moment" / "cf-browser-verification" ?
       带 cf_clearance cookie 重试（最多 2 次 + 退避）→ 仍挑战则当失败，绝不缓存
  → dvd_id 正则命中 ?
       命中 → 解析 meta / 内联 / 题材链接 / 解 HLS → 缓存 7 天
       未命中 → 软 404，返回 None（不当异常、不缓存）
```

**域名解析层**：`MISSAV_BASE_URLS` 多候选按序探测 + 跟随重定向 + TTL 6 小时缓存。历史上换过 `.tv` / `.cc` / `.asia` / `.sx`，不要硬编码域名。

### Locale 策略

`ja` 与 `zh-tw` 都抓都存：

| 字段 | 来源 |
|---|---|
| `title`（番号名） | `ja` —— 原站标题，贴近番号文化，不随翻译错位 |
| `synopsis`（剧情简介） | `zh-tw` —— 中文体验 |
| `genres[].name` / `stars[].name` | `ja` —— 题材 id `dm{N}` 不变，名称取 ja 更稳定 |
| `streams` / 封面 / 预告 | 与 locale 无关（CDN 按 code 命名） |

缓存 key 按 code 不按 locale，否则翻倍 MissAV 流量与被 CF 关照的概率。

### 缓存与限速

沿用现有 SQLite cache，新增 category：

| 资源 | TTL |
|---|---|
| `missav_detail:{code}` | 7 天（发布数据不变） |
| `missav_m3u8:{code}` | **10 分钟**（GUID 会变） |
| `missav_genre_index` | 6 小时（增量聚合） |
| `missav_home` | 20 分钟（推荐会变） |

单飞 + 1 req/s + 429/503 退避。客户端一启动就并发 3 个请求，没有缓存会立刻打爆 MissAV。

### API 契约

`/api/jav/explore`、`/genres`、`/detail` 默认切到 MissAV，保留 `?source=javbus` 显式回退。客户端改动最小，MissAV 全挂时可一键回退。

`GET /api/jav/detail/{CODE}` 扩展，原有字段全部保留：

```json
{
  "code": "RCTD-763", "title": "...", "cover": "https://fourhoi.com/rctd-763/cover-n.jpg",
  "synopsis": "剧情简介（og:description，zh-tw）",
  "release_date": "2026-09-21", "duration": "100分鐘",
  "studio": "ROCKET", "label": "ROCKET",
  "genres": [{"id": "dm156", "name": "巨乳"}, {"id": "dm55", "name": "4K"}],
  "stars":  [{"name": "九井スナオ", "slug": "dm13/actresses/九井スナオ", "avatar": "..."}],
  "has_chinese_subtitle": false, "has_english_subtitle": true,
  "cover_thumbs": ["https://fourhoi.com/rctd-763/cover-t.jpg"],
  "preview_url": "https://fourhoi.com/rctd-763/preview.mp4",
  "streams": {
    "hls_master": "https://surrit.com/<uuid>/playlist.m3u8",
    "hls_720p":   "https://surrit.com/<uuid>/720p/video.m3u8",
    "webpage":    "https://missav.ai/rctd-763/ja"
  },
  "missav": {"available": true, "slug": "rctd-763"},
  "_source": "missav"
}
```

新增端点：

```
GET /api/jav/explore?source=missav&page&limit           首页 / 列表
GET /api/jav/genres?source=missav                       自建题材索引（含 count）
GET /api/jav/genres/{genre_id}?source=missav            题材下影片
GET /api/jav/missav/home                                原始推荐分段（首页推荐区）
GET /api/jav/settings                                   下发 allowed_hosts / 当前域名 / locale
```

### JavBus 降级为兜底

- `search`：MissAV 命中率不足时回退（覆盖率预估 60-85%，待实测）
- `detail`：MissAV 软 404 时用 JavBus 详情，`missav.available=false`，UI 少一块不报错
- 磁链：继续用 JavBus 的 `uncledatoolsbyajax.php` —— **磁链是 JavBus 独有的，这是保留兜底最硬的理由**

## 客户端改造

### 阶段一：纯 Dart，可 Shorebird patch 热更

| 文件 | 改动 |
|---|---|
| `models/jav_models.dart` | 加 `synopsis` / `studio` / `label` / `genres[]` / `stars[]` / `streams` / `preview_url`，全部可空，现有 12 个 UI 文件零破坏 |
| `services/jav_api_service.dart` | `fetchDetail` / `fetchExplore` / `fetchGenres` 加 `source` 透传；新增 `fetchMissavHome`、`fetchSettings` |
| `pages/jav_detail_page.dart` | 新增 MissAV 详情区块（简介 / 厂牌 / 时长 / 真实题材 chips / 女优头像）；`_openPlayModal` 把 `webpage` 排第一 |
| `pages/jav_player_page.dart` | `onNavigationRequest` 白名单改为启动时拉 `/api/jav/settings` 的 `allowed_hosts`，失败回落现有硬编码 |
| `widgets/jav_discover_view.dart` | chip 文案去掉"JavBus"字样，接真实题材索引 |
| `widgets/jav_recommend_view.dart` | 首页接 Recombee 推荐分段 |
| `controllers/jav_controller.dart` / `jav_detail_controller.dart` | 新 RxList，接后台填充，不阻塞首屏 |

### 阶段二：原生 HLS 播放器（已定要做，接受重新安装）

引入 `media_kit` 即新增原生插件，**Shorebird patch 覆盖不了原生插件变更，必须走 `shorebird release` 出新 iOS 底包**（参考现有 `ci(release): build iOS only` 流水线）。

- 新增 `pages/jav_hls_player_page.dart`：`MediaPlayer.open(streams.hls_master)`，倍速 / 清晰度切换（`source842` / `source1280`）/ 画中画 / 自动旋转
- 详情页优先原生播放器，`webpage`（WebView 打开 MissAV 在线页）作兜底
- 失败回退链：`hls_master` 播放失败（GUID 过期 / surrit 限流）→ 后端重新解一次 m3u8 → 再失败降级 `webpage`
- 收益：广告全没了、可倍速、可后台、可离线进度记忆

阶段二上线后 `jav_player_page.dart` 的 WebView 不要删 —— 它是兜底，也是 dmm 预告 / jable 等第三方线路仍在用的路径。

### 别漏的两处

- `widgets/jav_safe_cover.dart` / `services/jav_safe_service.dart`：`fourhoi.com` 的图比 javbus 更露骨，脱敏模式（默认开启）必须覆盖新图源。
- 发布时同步 `lib/modules/search/models/omnihub_release_log.dart` 与 `CHANGELOG.md`。只改 md 的 push 会被 `paths-ignore '**.md'` 静默跳过 Shorebird 构建。

## 风险清单

| # | 风险 | 应对 |
|---|---|---|
| 1 | 题材 / 女优页 CF 403 | 自建题材索引，题材与 MissAV 同源 |
| 2 | surrit CDN 限流 | 不反代流，URL 回传手机直连 |
| 3 | HLS GUID 会变 | `missav_m3u8` TTL 10 分钟 + 播放失败重解 + 降级 webpage |
| 4 | 软 404 返回 200 | 用 `dvd_id` 正则判定，不看状态码 |
| 5 | 有效页面间歇被 CF 拦 | 挑战页检测 + `cf_clearance` 重试 + 严禁缓存挑战页 |
| 6 | code 归一化缺失 | 后端单一 `norm_code()` |
| 7 | 域名轮换 | `MISSAV_BASE_URLS` 多候选 + 探测 + 域名下发客户端 |
| 8 | Recombee key / scenario 变更 | 只承载首页推荐与热度排序，失效回退自建索引 |
| 9 | 覆盖率不足 | JavBus 兜底 + `missav.available=false` 静默降级 |
| 10 | PE-deflate 手法更换 | 解码失败降级到 webpage，不做死循环 |
| 11 | 原生播放器需新底包 | 分两阶段发布，阶段一独立可交付 |

## 落地顺序

| 步 | 内容 | 工时 | 独立可交付 |
|---|---|---|---|
| 0 | `scraper.py:437` 加 `/{locale}`，修现有播放按钮 | 15 分钟 | 是，单独热更 |
| 1 | `missav_scraper.py`：归一化 + 详情解析 + dvd_id 校验 + 挑战页检测 + PE-deflate 解 HLS | 1.5-2 天 | 是 |
| 2 | 题材索引表 + 用 JavBus 列表灌 500 个 code 预热 | 0.5 天 | 是 |
| 3 | Recombee 首页分段（含热度排序） | 0.5 天 | 是 |
| 4 | API 切默认 `source=missav` + `/api/jav/settings` 下发域名 + 缓存限速 | 0.5 天 | 是 |
| 5 | 客户端阶段一（纯 Dart，热更） | 1-1.5 天 | 是 |
| 6 | 联调 + 回归（磁链 / AI 找片 / 脱敏模式 / 一键速退） | 0.5-1 天 | — |
| 7 | `media_kit` 原生播放器 + `shorebird release` 新底包 | 1 天 + 一次 release | 是 |

## 验证

后端（`B=http://192.168.50.81:8923`）：

```bash
curl -s "$B/api/jav/detail/RCTD-763" | jq '{streams, missav, genres, synopsis}'
curl -s "$B/api/jav/genres?source=missav" | jq '.genres | length'
curl -s "$B/api/jav/missav/home" | jq '.segments[].items[].code'
```

- 50 个 code 打 `detail`，统计 `missav.available == true` 占比；低于 50% 说明 slug / locale 规则有问题
- 连打 200 次同 code，看 `_source` 是否切到 `nas_cache`，确认没打爆 MissAV
- `streams.hls_master` 的 URL 必须**用手机直连测试**，不要在 NAS 上测（NAS 出口会被限流）

客户端：

```bash
flutter analyze && flutter run
```

- 详情：命中时能看到简介 / 厂牌 / 真实题材；**未命中时必须只少一块区块，不能报错白屏**
- 播放：m3u8 在真机（家庭网络出口）能播；切清晰度可用；失败能回退 webpage
- 分类：题材标签可点、可筛选、按 count 排序（不显示计数）
- 首页：推荐分段正常填充且不阻塞首屏
- 安全模式：开启时 `fourhoi.com` 封面与剧照全部模糊，长按透视正常
## 实施进度

### 已完成（已部署到 NAS 生产环境）

**第 0 步：`scraper.py:437` 播放按钮修复**

`missav_url` 从 `f"https://missav.ai/{code.lower()}"` 改为 `f"{MISSAV_BASE_URLS[0]}/{code.lower()}/{MISSAV_LOCALE}"`，域名与 locale 提为 `.env` 可配（`MISSAV_BASE_URLS`、`MISSAV_LOCALE`）。实测 403 → 200，App 里现有的「MissAV 全网片源」线路从此可用。

**第 1 步：新增 `app/modules/jav/missav_scraper.py`**

含 `norm_code`、`_pe_deflate`、`_meta`、`_taxonomy`、`MissAvScraper`（域名探测 + 挑战页重试 + dvd_id 校验 + 双 locale + PE-deflate 解 HLS + 题材索引增量聚合）。

实测输出（`RCTD-763`）：8 个题材（`dm334 痴女`、`dm156 巨乳`、`dm55 4K` …）、女优 `dm13 九井スナオ`、厂牌 `dm88 ROCKET`、标签 `dm190 ROCKET`、`zh-tw` 简介 93 字、`hls_master` + `hls_alt` 两条 HLS。

**新增只读端点（未改动任何既有 javbus 端点，7 个既有端点回归全部 200）**

```
GET /api/jav/missav/detail/{code}?locale=    详情；未收录返回 {"missav":{"available":false}}
GET /api/jav/missav/genres                   题材索引，按 count 降序
GET /api/jav/missav/genres/{genre_id}/codes  题材反查番号
GET /api/jav/settings                        下发 allowed_hosts / 域名 / locale
```

缓存生效实测：第二次详情请求 16ms。

### 落地过程中修掉的四个 bug

1. **PE-deflate 索引偏移**：原实现从 `len(words)` 开始替换，比正确的 `len(words)-1` 多一轮，解出 `playlist='surrit://com.9a8a0702/...'` 这种垃圾串。改为 `range(len(words)-1, -1, -1)` 且用 `words[i]`。
2. **模板里单引号被转义**：解出来的字符串是 `source=\'https://...\`，正则匹配不到 URL。解码前先把 `\'` 还原成 `'`。
3. **题材索引 JSON 往返**：`set_cache` 走 JSON，读回来是 list 不是 set，`.add()` 报 `AttributeError: 'list' object has no attribute 'add'`，端点 500。改为全程用 list + `sorted()` 去重。
4. **图片代理 fourhoi.com 防盗链拦截**：`/api/img/proxy` 默认硬编码了 JavBus 的 Referer，导致请求 fourhoi.com 封面图时被 Cloudflare 拦截返回 403。已修复为命中 fourhoi.com 时自动携带 `https://missav.ai/` Referer，实测返回 200 OK 且成功落盘加密缓存。

### 实测确认的架构红线

`surrit.com` 从 NAS 固定出口访问返回 **403 Cloudflare "Sorry, you have been blocked"**（同一条 `playlist.m3u8`，从 Windows 端偶尔能 200）。**确认不能让 NAS 反代 HLS 流**，必须把 m3u8 URL 回传给手机直连播放。这条不是推测，是实测结论。

### 已完成阶段

- **第 0 步**：`scraper.py:437` 播放按钮修复（增加 locale 后缀），已部署上线。
- **第 1 步**：新增 `app/modules/jav/missav_scraper.py`，实现归一化、挑战页重试、dvd_id 校验、双 locale 解析、HLS 解密与题材反查。
- **第 2 步**：题材索引预热脚本 `scripts/preheat_genre_index.py` 运行完成，已收集 73 个 MissAV 官方题材并落盘缓存。
- **第 3 步**：Recombee 首页分段与热度排序已全面实现并上线：
  - 逆向签约算法与公共鉴权凭据，实现首页推荐与 `mobile-home-segments` 动态题材流；
  - 后端注册 `/api/jav/missav/home` 与 `/api/jav/genres/{genre_id}`，支持题材 ID (`dm156`) 自动映射与本地索引兜底；
  - 容器热启验证通过，实测 12 部推荐作品与 4 大题材分段秒级响应与 SQLite 缓存命中。
- **第 4 步**：后端 `/api/jav/detail/{code}` 与 `/api/jav/genres` 默认切至 MissAV 为主数据源，自动注入 JavBus 独占磁链与样张剧照，支持 soft-404 与异常无感回退至 JavBus。
- **第 5 步**：客户端阶段一（纯 Dart，支持热更交付）已全部实施并验证通过：
  - `jav_models.dart`：扩展 `JavDetail` 支持 `synopsis`、`studio`、`label`、`previewUrl`、`streams`、`structuredGenres`、`stars`、`isMissavAvailable`，新增 `JavStreams`、`JavGenreRef`、`JavStarRef`、`JavSettings`、`JavHomeSegment`、`JavHomeRecommendations` 模型。
  - `jav_api_service.dart`：新增 `fetchSettings` 与 `fetchMissavHome`，并在 `fetchDetail` 与 `fetchGenres` 中支持 `source` 与 `locale` 透传。
  - `jav_controller.dart`：后台静默填充 Recombee 动态题材流与精选推荐，内存快照秒开。
  - `jav_recommend_view.dart`：动态渲染 MissAV 题材分段流，修正历史遗留标签，支持点击直达题材专区。
  - `jav_player_page.dart`：初始化动态拉取 `/api/jav/settings` 下发域名与本地白名单合并防广告。
  - `jav_detail_page.dart`：新增剧情简介卡片、核心档案区补全制作/发行片商与主数据源标识，播放弹窗优先置顶 MissAV 线路。
  - `jav_discover_view.dart`：分类标签去除 JavBus 前缀。
  - 静态分析：`flutter analyze lib/modules/jav test/modules/jav` 0 警告 0 错误。
- **第 6 步**：全链路联调与回归测试已完成：
  - 详情页、题材索引、分段推荐、模糊封面代理、磁链提取与退回回退全链路回归验证通过；
  - 客户端自动化测试集全部通过（65/65 tests passed）。

### 后续待办

- 第 7 步：`media_kit` 原生 HLS 播放器引入与 `shorebird release` 新底包构建发布（阶段二）

### 已知缺口

- 字幕标记未实现：`has_chinese_subtitle` / `has_english_subtitle` 只出现在 Alpine.js 的 `:if` 表达式里，不是结构化数据，无法从 SSR HTML 可靠提取。当前靠 JavBus 侧的 `has_subtitles` 顶上。
- 部分番号 MissAV 无女优数据（`AGAV-182`、`SDDE-768` 实测 `stars` 为空）。
- 覆盖率尚未统计：需批量跑一批 code 统计 `missav.available == true` 占比。

### 后端改动位置与回滚

改动文件（均在 NAS，**非 git 仓库，改前已备份到 `.backup/`**）：

```
/tmp/zfsv3/nvme12/17786467800a/data/docker/omnihub/
├─ app/core/config.py                加 MISSAV_BASE_URLS / MISSAV_LOCALE
├─ app/modules/jav/scraper.py        :437 加 locale 后缀 + import
├─ app/modules/jav/missav_scraper.py 新文件
└─ server.py                         import + 4 个只读端点
备份标签：.backup/{config,scraper}.py.20260924-1533
重启：docker compose restart omnihub（约 5-11s 到 healthy）
```

