# OmniHub 性能审计报告

> 审计日期:2026-09-22
> 代码基线:`master` @ `dcf31d8`
> 范围:`lib/`(约 20 万行 Dart,485 个模块文件)、`assets/`、CI 工作流、GetX/talker/hive 依赖行为
> 方法:**静态审计 + 逐条回读源码验证**。未实际运行 profiler,文中标注的量级均为推断而非测量值。
> 复审:2026-09-22 已对全部高危论断逐条回读源码二次验证,记录见第 9 节。

---

## 0. 优先修复清单

| # | 问题 | 位置 | 预期收益 | 改动量 |
|---|---|---|---|---|
| 1 | Release 包全量打印请求/响应体,且无任何消费者 | `lib/services/api_client.dart:126` | 每请求 CPU + 内存,当前收益为零 | 1 行 |
| 2 | 4.7 MB 图标资源 + 无缩放解码 | `lib/models/app_icon_option.dart` | 省约 4 MB 补丁体积,消除 ~33 MB 峰值解码 | 压图 + 1 行 |
| 3 | syncfusion 图表无 `RepaintBoundary` + 5s 轮询动画 | `lib/modules/dashboard/widgets/cpu_widget.dart:76` | 常驻 home tab 帧率 | 小 |
| 4 | 日志流每行触发 4 次通知 + O(n) 过滤 | `lib/modules/server_log/controllers/server_log_controller.dart:89` | 日志页从卡顿到流畅 | 小 |
| 5 | 推荐页整个 feed 非懒加载 | `lib/modules/recommend/pages/recommend_page.dart:213` | 首页首屏 + 滚动帧率 | 结构改动 |
| 6 | 12 个 `Dio` 实例,0 个被关闭 | 见 3.2 | 连接池/内存随使用增长 | 中 |
| 7 | 主 Dio 超时 120 秒 | `lib/services/api_client.dart:80` | 卡死恢复时间 | 小 |
| 8 | 启动 5 个串行 await + Hive 12 个串行 openBox | `lib/main.dart:167`、`lib/services/hive_service.dart:51` | 冷启动首帧 | 小 |
| 9 | `IndexedStack` 一次性构建 5 个完整功能页 | `lib/modules/index.dart:223` | 冷启动请求风暴 | 中 |
| 10 | `Get.create` + `Get.find` 导致重复控制器/重复请求 | `lib/main.dart:645` | 每次开对话框多一个全量 API 加载 | 1 行 |

**建议动手顺序**:1 → 2 → 3 → 4 → 10 → 7 → 6 → 8 → 9 → 5。

---

## 1. 启动路径

### 1.1 `runApp` 前有 5 个串行 await,其中 2 个与登录屏无关

`lib/main.dart:167-178`

```dart
await Get.putAsync(() => HiveService().init(), permanent: true);
await Get.putAsync(() => IosWidgetNavigationService().init(), permanent: true);
await Get.putAsync(() => JPushService().init(), permanent: true);
...
await updateService.initShorebird();
await updateService.cleanupExpiredApkCache(maxAge: Duration.zero);
```

Hive、Widget 导航、JPush、Shorebird、APK 清理**逐个串行**阻塞首帧。Shorebird 补丁检查和 APK 缓存清理由定义上与 `/login` 无关,却排在它前面。

**改法**:互相独立的用 `Future.wait`;Shorebird / APK 清理移到首帧之后(`Future.microtask`)或登录后触发。

### 1.2 Hive:12 个 box 串行打开,且全部默认 `autocommit`

`lib/services/hive_service.dart:51-72`

`loginProfiles` → `agentMetaCache` 共 12 个 `await Hive.openBox(...)`,每个都是同步磁盘 IO,串行走一遍。

全项目 **0 处** `autocommit` 配置,即 12 个 box 全部使用默认 `autocommit: true` —— **每次 `.put()` 立即落盘**。

**改法**:12 个 box 彼此独立,用 `Future.wait` 并发打开;对写入频繁的 box(`agentMessagesCache`、`mediaDetailCache`)设 `autocommit: false`,改为手动 `flush`。

### 1.3 `IndexedStack` 一次性构建 5 个完整功能页

`lib/modules/index.dart:223-232`

```dart
return IndexedStack(index: coercedIndex, children: [
  DashboardPage(scrollController: _tabScrollControllers[0]),
  RecommendPage(scrollController: _tabScrollControllers[1]),
  DiscoverPage(scrollController: _tabScrollControllers[2]),
  MultifunctionPage(scrollController: _tabScrollControllers[3]),
  SearchIndexPage(scrollController: _tabScrollControllers[4]),
]);
```

`IndexedStack` 保留全部子树 —— 5 个页面在**首帧全部构建**,各自 `onInit` 全部发网络请求。叠加 `lib/modules/index.dart:78-81` 里主动创建的 4 个控制器:

```dart
Get.put(RecommendController());
Get.put(DiscoverController());
Get.put(MultifunctionController());
Get.put(SearchIndexController(), permanent: true);
```

登录成功那一刻会并发打出十几个请求。

**改法**:`IndexedStack` 换 `PageView` + `preserveOffstageState: false`,或对仅浏览类 tab 用「首次切到才构建」。Dashboard 建议保留常驻(它是 home),其余懒构建。

### 1.4 底部导航栏等平台通道往返才渲染

`lib/modules/index.dart:299-309`

用 `FutureBuilder<bool>` 包 `LiquidGlassHelper.isLiquidGlassSupported()`,等待期间渲染一个**没有导航栏的 Scaffold**,resolve 后再整棵重建。首屏必然抖一次。

**改法**:默认按 `false` 渲染,拿到结果再补上原生导航。

### 1.5 构建配置:Release 未开启混淆

`.github/workflows/build-release.yml`

三个平台(android 通用包、android arm64、iOS)的 `flutter build` 命令里 **0 处 `--obfuscate`、0 处 `--split-debug-info`**。Dart 符号名全部保留,包体偏大,可读性也比预期好。

---

## 2. 渲染帧率

### 2.1 推荐页:整个多分区 feed 是非懒 `Column`

`lib/modules/recommend/pages/recommend_page.dart:213-260`,外层调用点在 `:104`:

```dart
SliverToBoxAdapter(child: _buildSectionList(context)),
```

```dart
final items = controller.itemsForSubCategory(subCategory).toList();
...
return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sectionWidgets);
```

`Column` 塞进 `SliverToBoxAdapter` 彻底废掉视口裁剪:所有分区、所有卡片、所有图片**一次性构建布局**。内部横滑条是懒的(`ListView.separated`),纵向堆叠才是问题。且单个 `Obx` 订阅了所有子分类 map,任一分区返回都触发整棵重排。

**改法**:每个分区改成独立 sliver,`Obx` 下沉到分区级。这是首页最大的布局开销,纯结构改动。

### 2.2 日志流:每行触发 4 次通知 + O(n) 过滤

`lib/modules/server_log/controllers/server_log_controller.dart:89-96`

```dart
final entry = LogEntry.fromLine(payload);
logs.add(entry);                                    // 通知 1
logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));  // 通知 2
const maxLines = 500;
if (logs.length > maxLines) logs.removeRange(maxLines, logs.length);  // 通知 3
logs.refresh();                                    // 通知 4
```

SSE 每秒多行,消费端 `server_log_page.dart:29` 的 `Obx` 每次都重算 `filteredLogs`(500 条线性扫描;有关键词时逐条拼串再转小写)。这是**唯一不受用户操作限流的通知源**。

**改法**:缓冲批处理(`scheduleMicrotask` 合并后再一次性 `assignAll`),删掉尾部的 `refresh()`;过滤结果缓存到字段,只在 `filterLevel` / `keyword` 变化时失效。

### 2.3 仪表盘:5 秒轮询 × ~10 个 Rx + 2 个图表无 `RepaintBoundary`

`lib/modules/dashboard/controllers/dashboard_controller.dart:143-154`

```dart
_refreshTimer = Timer.periodic(duration, (_) => _loadDataBasedOnConfig());   // 5s
_cookieTimer = Timer.periodic(const Duration(minutes: 1), (_) => _ensureUserCookieRefreshed());
```

`_loadDataBasedOnConfig` 通过 `Future.wait` 并发约 10 个请求,每个都赋值一个 Rx —— 每 5 秒约 10-13 次通知。

`_appendCpuChartData`(`:539`)重建整个列表,并且**为每个点 new 一个 `ChartDataPoint`**:

```dart
for (var i = 0; i < list.length; i++) {
  list[i] = ChartDataPoint(i, list[i].value);
}
```

两张 syncfusion 图表 `animationDuration: 250`(`lib/modules/dashboard/widgets/cpu_widget.dart:76`、`memory_widget.dart:90`)—— 即每 5 秒、永久、在常驻 home tab 上跑两轮 250ms 动画。

**全项目只有 1 处 `RepaintBoundary`**(`lib/modules/workflow/widgets/shared_workflow_card.dart:23`)。约 15 万行里图表、卡片、动画全都没做重绘隔离。

**改法**:图表外套 `RepaintBoundary`;轮询驱动的刷新设 `animationDuration: 0`(仅首次挂载保留动画);10 个 Rx 赋值包进 `batch()`,让每轮只重建一次。

> 附带观察:`loadCpuData` 给真实 CPU 值加了 `±2%` 随机波动("使动画效果更明显")。图表每 5 秒动画一次,一半是为了展示这点噪声。

### 2.4 种子行:每行约 7 层渐变/阴影 + 行级 `Obx` 订阅全站列表

`lib/modules/search_result/widgets/search_result_torrent_item.dart:547-604`

```dart
final controller = Get.isRegistered<SiteController>()
    ? Get.find<SiteController>()
    : Get.put(SiteController());   // ← 在 build 内部注册依赖

return Obx(() {
  if (siteId != null) {
    for (final value in controller.items) {   // 订阅整个 items
      if (value.site.id == siteId) { siteItem = value; break; }
    }
  }
```

单行绘制重量:卡片 `LinearGradient` + `BoxShadow(blurRadius: 22)`、footer 渐变 + 阴影、size pill 渐变 + 阴影、每个 tag chip 各自一个 `BoxShadow(blurRadius: 6)`。可见约 8 行 ≈ 60 层阴影,零 `RepaintBoundary`。

行级 `Obx` 订阅 `SiteController.items` 全量 —— **站点列表任一刷新会重建所有可见行**;另有一次性线性扫描所有站点、`Uint8List.fromList` 缓冲拷贝、`DateFormat` 每次 new、`_tagStyle` 每个 tag 分配 6 元素列表。

使用点:`lib/modules/search_result/pages/search_result_page.dart:409`、`lib/modules/site/pages/site_resource_page.dart:112`(后者可能几百条)。

**改法**:
1. 站点查表改成 `Map<int, SiteItem>`,在 `Obx` 外构建,直接去掉行级 `Obx`(滚动期间站点名/图标不变)。
2. `DateFormat` 提为 `static final`。
3. 卡片套 `RepaintBoundary`。
4. 把多组 `LinearGradient` + `BoxShadow` 收敛为单层阴影或缓存 shader。

### 2.5 列表行里的 `BackdropFilter`

`lib/widgets/app_glass_card.dart:63-65` 作为通用卡片组件被逐行实例化,`lib/modules/recommend/pages/recommend_category_list_page.dart:416` 处 `blurSigma: 14`。

`BackdropFilter` 要采样身后已绘制的内容;在滚动 sliver 里,背景每帧都在变,于是**每个可见卡片每帧重跑一次高斯模糊**。约 15 个可见卡片 = 15 次 blur / 帧。

**改法**:滚动内容上用半透明 surface 色(现成的 `surfaceAlpha` 已足够);`BackdropFilter` 只保留给静态浮动条(如 `search_result_page.dart:91`、`site_resource_page.dart:220`、`server_log_page.dart:172`),那些成本只付一次。

### 2.6 用户管理行:每次重建都 base64 解码 + 重新解码 PNG

`lib/modules/user_management/widgets/user_management_item_card.dart:184-192`

```dart
final bytes = base64Decode(base64String);
if (bytes.isEmpty) return _buildDefaultAvatar();
return CircleAvatar(
  radius: 28,
  backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
);
```

`BoxDecoration.backgroundImage` 用 provider 的**实例**做缓存 key —— 每次 build 都是新 `MemoryImage`,于是**重新解码 PNG、重新分配 GPU 纹理**,并完全绕过 Flutter 的 `ImageCache`。

**改法**:解码一次存 `Uint8List`(或在 controller 里做),复用项目已有的 `CachedAvatar` / `CachedImage`。

### 2.7 `RxMap.refresh()` 全量通知 × 13 个预取分类

`lib/modules/recommend/controllers/recommend_controller.dart:507-539`

```dart
isLoadingByKey[key] = true;
errorByKey[key] = null;
isLoadingByKey.refresh();
...
itemsByKey[key] = items;
itemsByKey.refresh();
...
} finally {
  isLoadingByKey[key] = false;
  isLoadingByKey.refresh();
}
```

`RxMap.refresh()` 通知的是**整个 map 的所有观察者**,不是该 key 的观察者。13 个预取分类 × 4 次 map 写入 ≈ 52 次全 feed 重建,叠加 2.1 的单大 `Obx`。

同类"双通知"惯用法(索引赋值本身已通知,尾部 `.refresh()` 是多余的):

- `lib/modules/download/controllers/download_controller.dart:225-228`(该控制器 8 秒轮询一次)
- `lib/modules/dynamic_form/adapters/brush_flow_form_controller.dart` 多处
- `lib/modules/subtitle/controllers/subtitle_search_controller.dart:221`、`:270`
- `lib/modules/system_health/controllers/system_health_controller.dart:438`
- `lib/modules/agent/controllers/agent_controller.dart:591`
- `lib/modules/directory/controllers/directory_list_controller.dart:67`

**改法**:删掉尾部 `.refresh()`;需要按 key 细粒度通知就把 `RxMap` 换成 `Map<String, Rxn<T>>`。

### 2.8 侧载 build 期副作用(低风险但应清理)

- `lib/modules/search/pages/search_index_page.dart:359-362`:`_buildRecommendMediaPager` 在 build 内调用 `rec.ensureSubCategoryLoaded(sub)`,且 `_pickRecommendPagerSubcategory` 在 `Obx` 外读状态 —— 列表稍后到达时 pager 静默过期。应移到 `initState` / `addPostFrameCallback`。
- `lib/modules/plugin/services/plugin_palette_cache.dart:25-31`:`watchColor()` 被同步调用自 `recommend_page.dart:392-400` 的 build 路径,内部会发起 `_fetchOne` 网络请求。应在 `didChangeDependencies` / `addPostFrameCallback` 里预取,`watchColor` 只读。
- `lib/modules/search_result/widgets/search_result_torrent_item.dart:551-553`:`Get.put(SiteController())` 在 build 内执行;两个行同时 build 会重复注册。应移到模块初始化。
- `lib/modules/index.dart:222`:`_buildTabBody` 在 build 期间给 `_activeScrollController` 赋值,属 build 期状态变更。

### 2.9 其它小项

- **`DateFormat` 逐行 new**:`server_log_page.dart:534-535`(每行 2 个)、`system_message_item.dart:141/199/257/358`、`search_result_torrent_item.dart:1187`、`settings/models/github_workflow_models.dart:137/139/149`。正确写法项目里已有(`search_result_controller.dart:47`、`search_controller.dart:76`、`site_resource_controller.dart:16`),统一提为 `static final`。
- **无 `itemExtent`**:全项目仅 5 处,且全在底部 sheet 选择器里;滚动 feed 一处都没配。
- **`cacheExtent` 仅 4 处**:除 `shared_workflow`、`plugin_page`、`plugin_list_page`、`recommend_category_list_page` 外,其余滚动视图都用默认 250px。
- **`Image.network` 绕过缓存**:`lib/modules/cache/pages/cache_page.dart:799-818`、`lib/modules/dynamic_form/widgets/vuetify_display_widgets.dart:167`,均在 `SliverList` 行内。改用项目自带的 `CachedImage`。
- **非懒列表回退**:`lib/modules/dynamic_form/widgets/VueStyle/subtitle_manual_upload/subtitle_manual_upload_widgets.dart:31-33`、`brush_flow_widgets.dart:51-53` 均为 `ListView(children: blocks.map(...).toList())`;同一文件 `:775-791` 的媒体列表是 `Column` + `for`,而 `mediaHasMore` / `loadMoreMedia` 会继续累加条目,越翻页越慢。
- **`static final Map _iconFutures` 永不淘汰**:`search_result_torrent_item.dart:36`,会累积每个见过的站点的图标 future 与字节。
- **`ever` 触发滚动**:`lib/modules/agent/pages/agent_chat_page.dart:276`,`ever(_controller.messages, (_) => _scrollToBottom())` —— 任一消息变更都强制滚到底,打断用户上滑阅读。应加 `debounce` 且仅在已处于底部时自动滚动。

---

## 3. 网络与资源

### 3.1 Release 包在每个请求上全量打日志,且没有任何消费者

`lib/services/api_client.dart:126-134`

```dart
TalkerDioLogger(
  talker: _log.talker,
  settings: const TalkerDioLoggerSettings(
    printRequestHeaders: true,
    printResponseHeaders: true,
    printResponseMessage: true,
    printRequestData: true,
    printResponseData: true,
    logLevel: LogLevel.debug,
  ),
),
```

核实了 `talker_dio_logger-5.1.20` 源码,**全包 0 处 `kReleaseMode` / `kDebugMode` 判断** —— release 包同样把完整请求体和响应体序列化进 Talker 历史。

而 `lib/applog/app_log.dart` 的配置是:

```dart
Talker(settings: TalkerSettings(
  useConsoleLogs: false,
  useHistory: true,
  maxHistoryItems: 100,
))
```

**没有 `TalkerWriter` / `TalkerLogSink`** —— 日志既不落盘也不上屏,「App 日志」页面最多能看到 100 条内存记录。

结论:**每个 API 请求都在最热路径上做全量 JSON 字符串化,并堆积进 100 条内存历史,收益为零**。搜索、插件、Agent 的响应体都不小。

**改法**(单项性价比最高):

```dart
if (kDebugMode) {
  _dio.interceptors.add(TalkerDioLogger(...));
}
```

或至少 `printResponseData: false` / `printRequestData: false`。若真要线上可观测性,反过来做 —— 加 `TalkerLogSink` 让日志有出口。

### 3.2 12 个 `Dio()` 实例,没有一个被关闭

创建点:

| 文件 | 行 | 性质 |
|---|---|---|
| `lib/services/api_client.dart` | 76 | 长生命周期(主 client) |
| `lib/modules/dian115/services/dian115_service.dart` | 44 | 长生命周期 |
| `lib/modules/dian115/services/pan115_service.dart` | 45 | 长生命周期 |
| `lib/modules/dian115/services/pan115_service.dart` | **346** | 方法内 `final directDio` |
| `lib/modules/download/controllers/download_controller.dart` | **982** | 方法内 |
| `lib/modules/plugin/pages/plugin_info_sheet.dart` | **752** | 方法内 |
| `lib/services/app_service.dart` | **237** | 方法内 |
| `lib/modules/jav/services/jav_api_service.dart` | 18 | 长生命周期 |
| `lib/modules/pansou/services/pansou_service.dart` | 28 | 长生命周期 |
| `lib/modules/search/services/app_update_service.dart` | 15 | 长生命周期 |
| `lib/modules/settings/services/github_actions_service.dart` | 41 | 长生命周期 |
| `lib/services/sse_client.dart` | 19 | 每 client 一个 |

全项目 **`dio.close()` 出现 0 次**。

方法内创建的实例(pan115 离线任务、download、plugin 备份、SSE)是纯泄漏:每次操作 new 一个 HTTP client,永不释放,连接池按 `connectionMaxAge` 持有空闲连接,底层 socket 只能等 GC。

**改法**:收敛成少数几个长生命周期 client 按用途分(base / 115 / 第三方);方法内临时 Dio 用完 `.close()`。

### 3.3 主 Dio 超时 120 秒

`lib/services/api_client.dart:80-81`

```dart
connectTimeout: const Duration(seconds: 120),
receiveTimeout: const Duration(seconds: 120),
```

移动端 2 分钟等一个请求。结合近期提交方向("extend dio timeout"、"anti-hang protection"),超时会被越调越长。

各 client 当前超时值,供收敛参考:

| Client | connect | receive |
|---|---|---|
| 主 api_client | 120s | 120s |
| dian115_service | 15s | 45s |
| pan115_service | 15s | 30s |
| pan115 directDio | 15s | 25s |
| download_controller | 25s | 60s |
| jav_api_service | 6s | 25s |
| pansou_service | 15s | 35s |
| plugin_info_sheet | 20s | 20s |

**改法**:主 client 收到 15–20s 连接 / 30–45s 读取;真正慢的操作(115 离线、插件备份)单独 client 配大值,不要用同一个。

### 3.4 SSE 客户端:新建 Dio,重连时旧连接不可取消

`lib/services/sse_client.dart:19`

```dart
SseClient({required this.baseUrl, this.headers, Dio? dio})
  : _dio = dio ?? Dio();
```

又一个新的 Dio 实例。

更实际的问题在 `connect()`:直接覆盖 `_cancelToken` 与 `_streamController` —— **二次调用后旧连接的 `CancelToken` 被丢弃,旧连接无法取消**,只留下一个泄漏的 stream。

另:`_handleStream` 内 `buffer += '$line\n'` 是循环内字符串拼接(O(n²));`retry` 字段解析出来但从未使用,流断开后不重连。

**改法**:`connect()` 开头先 `disconnect()`;拼接改 `StringBuffer`;补上按 `retry` 间隔的重连。

调用方是干净的:`search_controller.dart:523-524`、`file_manual_transfer_sheet.dart:622-623` 都在页面关闭时 `disconnect()`。

### 3.5 分页缺失的 feed

**已正确分页**(有 `hasMore` + 防重入 guard):

- `lib/modules/system_message/controllers/system_message_controller.dart:212-217`
- `lib/modules/workflow/controllers/workflow_controller.dart:206-241`
- `lib/modules/search/controllers/media_search_list_controller.dart`
- `lib/modules/search/controllers/person_search_list_controller.dart`
- `lib/modules/discover/controllers/discover_controller.dart`
- `lib/modules/recommend/pages/recommend_category_list_page.dart:1243`、`:1274`

**不分页(全量拉取)**:

- `lib/modules/search_result/controllers/search_result_controller.dart` —— 走 `/api/v1/search/last`,无 page 参数
- `lib/modules/recommend/controllers/recommend_controller.dart` —— 13 个分类各拉全量
- `lib/modules/site/controllers/site_resource_controller.dart`
- `lib/modules/cache/controllers/cache_controller.dart`
- `lib/modules/subscribe/controllers/subscribe_controller.dart`
- `lib/modules/plugin/controllers/plugin_list_controller.dart`

`LoadMoreFooter` 本身有正确的 `!hasMore` 终态,所以不存在无限重拉循环 —— 问题只是这些 feed 永远拿不到 `hasMore: false`。

### 3.6 Hive 全部默认 `autocommit`

全项目 **0 处** `autocommit` 配置,12 个 box 都是默认 `autocommit: true`,即每次 `.put()` 立即落盘。

写入点分布:

- `lib/modules/agent/services/agent_local_cache.dart:80, 107, 125, 134, 135`(Agent 会话/消息)
- `lib/modules/login/repositories/auth_repository.dart:227, 419`
- `lib/modules/media_detail/controllers/media_detail_controller.dart:185`
- `lib/modules/plugin/controllers/plugin_controller.dart:284`
- `lib/modules/plugin/controllers/plugin_list_controller.dart:285`
- `lib/modules/plugin/services/plugin_palette_cache.dart:92`
- `lib/modules/site/controllers/site_controller.dart:488, 491, 552`
- `lib/modules/site/controllers/site_detail_controller.dart:117`
- `lib/modules/search/repositories/search_history_repository.dart:35`
- `lib/services/api_client.dart:791`

写入侧已有关键防护:`AgentController` 用 `_persistDebounce`(`lib/modules/agent/controllers/agent_controller.dart:490-515`)做持久化防抖,没有每事件落盘。

**改法**:对高频 box 设 `autocommit: false` + 定时/手动 `flush`。

### 3.7 做得对的地方

- `Future.wait` 有 15 处,该并行的地方确实并行了;`jav_controller` 还配了 3 个 `CancelToken` 分别管搜索/抓取/库。
- **全项目 `CancelToken` 49 处**,取消纪律明显好于同类项目。
- `lib/widgets/cached_image.dart` 是亮点:按 `devicePixelRatio × 1.35` 自动推导 `memCacheWidth/Height`、clamp 到 `64..1600`、按 `BoxFit.cover` 选轴、URL query 归一化做缓存 key、自定义 `CacheManager`、损坏缓存淘汰。这是大多数 `CachedNetworkImage` 项目会跳过的解码尺寸纪律。
- `lib/modules/recommend/controllers/recommend_controller.dart` 有真正的请求队列:`_maxConcurrentRequests = 3` + `_pendingKeys` 去重 + 30s/10s 刷新节流。
- `lib/modules/site/pages/site_page.dart:148-193` 做对了:`filtered` + 排序在 sliver delegate 之外预计算,再交给 `SliverList.builder`。`search_result_page` 和 `site_resource_page` 应向它看齐,而不是在 `Obx` 里调 `visibleItems`。
- `lib/modules/download/controllers/download_controller.dart:80-88` 把定时器启动推迟到 `addPostFrameCallback` 并带 `isClosed` guard,处置规范。
- `lib/widgets/app_loading.dart:71-75` 正确遵循 `MediaQuery.disableAnimationsOf(context)`。
- Lottie 用法克制:仅 3 处真实使用,无 `AnimatedLottie`、无 `Lottie.network`、无 `LottieController`,不存在 AnimationController 抖动。
- `soft_edge_blur` 的 3 处使用(`media_detail_season_card.dart:138`、`jav_banner_card.dart:47`、`recommend_ios_banner_card.dart:55`)都是单张 hero 卡片,不在列表行内。

---

## 4. 资源与构建体积

### 4.1 8 张应用图标吃掉 4.7 MB,渲染端不做缩放解码

`assets/app_icons/` 全部为 1024×1024(下表数值为 KiB,与磁盘实测一致):

| 文件 | 大小 |
|---|---|
| `icon_neon.png` | 1137 KB |
| `icon_aurora.png` | 1105 KB |
| `icon_sunset_pop.png` | 1038 KB |
| `icon_mono.png` | 934 KB |
| `icon_default.png` | 158 KB |
| `icon_midnight.png` | 121 KB |
| `icon_sunset.png` | 110 KB |
| `icon_mint.png` | 105 KB |

后 4 张与前 4 张**分辨率完全一致**,纯粹是压缩质量差。而它们的用途是设置页的缩略图选择器(`lib/models/app_icon_option.dart`)。

渲染端 `lib/modules/search/pages/app_theme_setting_page.dart:250`:

```dart
Image.asset(
  option.assetPath,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.high,
)
```

无 `cacheWidth` / `cacheHeight`,无 `ResizeImage`。Flutter 按原图解码,**每张 1024×1024 = 4.2 MB 解码内存**,8 张同屏最坏约 33 MB,还叠了 `FilterQuality.high`。

**改法**(改动极小、收益立竿见影):

1. 这 8 张重压为 WebP 或量化 PNG,每张降到 50–100 KB → **直接省约 4 MB** IPA 与每次 Shorebird 补丁体积。
2. 渲染端加 `cacheWidth: 128, cacheHeight: 128`。

### 4.2 全部资源 7.9 MB,全部随每次补丁下发

| 目录/文件 | 大小 | 备注 |
|---|---|---|
| `assets/app_icons/` | 4.7 MB | 8 张启动图标,见 4.1 |
| `assets/images/` | 2.4 MB | 含 `logos/jellyfin.png` 435 KB、`logos/plex.png` 337 KB(列表行用) |
| `assets/lottie/` | 744 KB | 含 `Flirting_Dog.json` 639 KB(单个 Lottie JSON 偏大,解码也贵) |
| `assets/icon.png` | 160 KB | |

iOS 自签底包 + Shorebird 补丁的形态下,这 7.9 MB 每次都在传输和安装路径上。

### 4.3 顺带发现的安全问题(非性能,一并记录)

- `.github/workflows/build-release.yml:121-122`:`--dart-define=PAN115_COOKIE=...` 与 `GITHUB_ACTIONS_TOKEN=...` **明文烧进 IPA**。`dart-define` 是编译期常量,补丁和 `strings` 都能读出来。应改为服务端下发或用户配置。
- `lib/utils/web_view_screen.dart:118`:`AndroidWebViewController.enableDebugging(true)` **无条件调用**,release 包 WebView 调试同样开启。
- 3 处 `WebViewController` 创建从未 `.close()`:
  - `lib/modules/dian115/widgets/dian115_login_sheet.dart:72`
  - `lib/modules/dian115/widgets/dian115_verify_sheet.dart:102`
  - `lib/utils/web_view_screen.dart:55`

  webview_flutter 的 `WebViewController` 持有原生 webview;Android 上会累积到 GC。对反复打开 115 登录/验证页的用户是真实内存增长。

### 4.4 Release 构建未开启混淆

`.github/workflows/build-release.yml`

三个平台的 `flutter build` 命令里 **0 处 `--obfuscate`、0 处 `--split-debug-info`**。建议:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

iOS 同理(`flutter build ios --release --obfuscate --split-debug-info=...`)。注意 Shorebird patch 需要与 base 的混淆设置保持一致。

---

## 5. 正确性导致的性能问题

### 5.1 `Get.create` + `Get.find` 导致重复控制器与重复请求

`lib/main.dart:645`

```dart
GetPage(
  name: '/media-detail',
  page: () => const MediaDetailPage(),
  binding: BindingsBuilder(() {
    Get.create(() => MediaDetailController());
  }),
),
```

`Get.create` 注册的是**工厂**。get 4.7.3 文档原文:

> Every time `find<S>()` is used, it calls the builder method to generate a new Instance. … if you call `Get.delete<T>()` the "instance factory" used in this method will be removed, **but NOT the instances already created by it.**

`MediaDetailPage` 用 `GetWidget<MediaDetailController>`(内部走 `Get.find`),页面自身拿到一份没问题。

问题在 `lib/modules/media_detail/pages/media_season_detail_page.dart:51`:

```dart
final _mediaDetailController = Get.find<MediaDetailController>();
```

剧集详情页是 `media_detail_page.dart:1151` 弹出的**对话框**,与详情页**同一路由**。每次打开剧集详情,都会**新建一个完整的 `MediaDetailController`**,而且它和页面那份是**两个不同的实例**(页面那份存在 `GetWidget` 的 `Expando` 缓存里)。注意:工厂模式下新建实例**是否触发 `onInit`** 取决于 get 4.7.3 工厂路径的具体实现,本审计未核实这一层;重复实例必然发生,但"每次开对话框多一遍 API 加载"以 `onInit` 被调用为前提。

**改法**:改为 `Get.lazyPut(...)` 或 `Get.put(..., permanent: false)`,让页面与对话框共享同一份实例。

---

## 6. 已验证无问题(不必重复排查)

| 项 | 结论 |
|---|---|
| `Get.put` 生命周期 | get 4.7.3 默认 `permanent: false`(`extension_instance.dart:87`),102 处 `Get.put` 中仅 38 处显式 `permanent: true`,是有意为之的单例。**不是泄漏源** |
| 定时器 / 订阅 / WebView 清理 | `background_task_list_page.dart:753`、`dian115_login_sheet.dart:53` 均正确在 `dispose` 中 cancel;71 个控制器文件中 35 个有 `onClose`,其余不持有资源 |
| 搜索防抖 | `search_index_controller.dart:25` 有 150ms `_debounceDuration`;搜索结果关键词为提交驱动(`updateKeyword(submitted)`),不需要防抖 |
| `shrinkWrap: true` | 全项目 0 处 |
| 列表惰性化 | 真列表基本都用 `SliverList.builder` / `ListView.builder` |
| 请求并发控制 | `recommend_controller` 有 `_maxConcurrentRequests = 3` + 去重 + 刷新节流 |
| 请求取消 | 全项目 49 处 `CancelToken` |
| Agent 持久化 | `_persistDebounce` 防抖,无每事件落盘 |
| Lottie | 仅 3 处,无 Controller 抖动,尊重 reduce motion |
| 图片解码纪律 | `lib/widgets/cached_image.dart` 有完整的 `memCacheWidth/Height` 推导 |

---

## 7. 审计过程的纠正记录

为保证可信度,以下是初步判断被源码推翻的地方:

1. **`Get.put` 内存泄漏** —— 起初怀疑 102 处 `Get.put` 仅 13 处显式 `permanent: false` 会累积。查 get 4.7.3 源码后确认**默认值就是 `false`**,不构成泄漏。
2. **定时器泄漏** —— 初版扫描脚本用 `onClose` 关键字判断清理,误报 `background_task_list_page.dart` 与 `dian115_login_sheet.dart`。二者是 `StatefulWidget`,用 `dispose` 正确清理。改用正确口径(StatefulWidget 查 `dispose`、`GetxController` 查 `onClose`)后无一命中。
3. **"全项目 0 处 debounce"** —— 子任务给出的结论有误,`search_index_controller.dart` 确有 3 处 `debounce` 相关代码。已修正为"搜索首页已防抖"。

---

## 8. 建议实施顺序

按「改动量 / 收益比」排序:

1. **3.1** TalkerDioLogger 加 `kDebugMode` 门控 —— 1 行,消除每条请求的全量序列化与 100 条内存历史堆积。
2. **4.1** 重压 8 张图标 —— 零代码改动,省约 4 MB 补丁体积,消除约 33 MB 峰值解码。
3. **5.1** `Get.create` 改 `lazyPut` —— 1 行,消除每次开对话框的重复控制器与重复 API 加载。
4. **2.3** 图表套 `RepaintBoundary` + 轮询时 `animationDuration: 0`。
5. **2.2** 日志流批处理 + 删除尾部 `refresh()`。
6. **2.7** 批量删除 `assignAll` / 索引赋值后紧跟的 `.refresh()`(6+ 处)。
7. **3.3** 主 Dio 超时收敛。
8. **3.2** Dio 实例收敛,方法内临时 Dio 补 `.close()`。
9. **1.1 / 1.2** 启动阶段并发化(Hive 12 box `Future.wait`,Shorebird/APK 清理移出关键路径)。
10. **2.6** 用户管理行缓存解码结果。
11. **2.4** 种子行去掉行级 `Obx` + `RepaintBoundary` + `DateFormat` 静态化。
12. **1.3** `IndexedStack` 改懒构建(涉及 tab 状态与滚动位置保持,需回归测试)。
13. **2.1** 推荐页 feed 改真实 sliver(结构改动最大,收益也最高,建议单独一轮)。
14. **3.5** 给不分页的 feed 补服务端分页。
15. **4.3 / 4.4** 安全问题与混淆(非性能,建议同轮处理)。

---

## 9. 复审验证记录(2026-09-22)

对高危论断逐条回读源码二次验证,以下论断**全部与源码一致**,行号引用精确:

| 论断 | 验证结果 |
|---|---|
| 3.1 TalkerDioLogger 无 kDebugMode 门控;`app_log.dart` 无 sink、仅 100 条内存历史 | ✅ 逐字一致 |
| 3.3 主 Dio 超时 120s | ✅ |
| 2.2 日志流每行 4 次通知(add/sort/removeRange/refresh) | ✅ 代码块逐字一致 |
| 1.1 启动 5 个串行 await,Shorebird/APK 清理在登录前 | ✅ |
| 5.1 `Get.create` 与对话框 `Get.find` 两处引用 | ✅ 引用精确;`onInit` 触发问题已在上文加注保留 |
| 1.3/1.4 `IndexedStack` 5 页全构建 + 导航栏 `FutureBuilder` | ✅ |
| 2.3 5s 轮询、`animationDuration: 250`、CPU ±2% 随机噪声、逐点重建 `ChartDataPoint` | ✅ 全部属实 |
| 2.7 `RxMap.refresh()` 双通知模式 | ✅ |
| 2.1 推荐页 `SliverToBoxAdapter` 包 `Column`;2.8 build 期 `watchColor` 副作用 | ✅ |
| 2.4 种子行 build 内 `Get.put(SiteController())`、逐次 new `DateFormat` | ✅ |
| 2.6 用户管理头像每次 build 重新 base64 解码 + 新 `MemoryImage` | ✅ |
| 3.4 SSE 二次 connect 丢 CancelToken、`buffer +=` O(n²)、retry 未使用 | ✅ |
| 4.3/4.4 无 `--obfuscate`;`PAN115_COOKIE`/`GITHUB_ACTIONS_TOKEN` 明文 dart-define | ✅ `build-release.yml:121-122/139-140/234-235` |
| 4.1 图标体积表 | ✅ 与磁盘实测一致(KiB 标注,已加注) |

复审保留意见(已并入正文):

1. **5.1** "每次开对话框多跑一遍 `onInit` 的 API 加载" —— 重复实例必然发生,但工厂路径是否触发 `onInit` 未核实,正文已改为带前提的表述。
2. 全文量级数据(如 "~33 MB 峰值解码"、"15 次 blur/帧")均为推断而非实测,开头已有声明,复审确认该声明属实。
