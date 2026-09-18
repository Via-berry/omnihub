import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_banner_card.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_now_playing_card.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_safe_cover.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

class JavMainPage extends GetView<JavController> {
  const JavMainPage({super.key});

  static const Color _themeColor = Color(0xFF061815);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeColor,
      extendBodyBehindAppBar: true,
      appBar: _buildTopAppBar(context),
      body: Obx(() {
        if (controller.isLoading.value && controller.bannerItems.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
          );
        }

        if (controller.errorMsg.value.isNotEmpty && controller.bannerItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.wifi_exclamationmark, color: Colors.amberAccent, size: 48),
                    const SizedBox(height: 14),
                    const Text(
                      '无法连接到后端服务',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      controller.errorMsg.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _showServerConfigDialog(context),
                          child: const Text('设置地址', style: TextStyle(fontSize: 13, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: controller.refreshData,
                          child: const Text('重试连接', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (controller.currentMainTab.value == 1 && !controller.isSearching.value) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 300) {
                controller.loadMoreLibraryMovies();
              }
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchBarSection(context),
              ),
              if (controller.isSearching.value)
                ..._buildSearchResultsSlivers(context)
              else if (controller.currentMainTab.value == 0) ...[
                SliverToBoxAdapter(
                  child: _buildTagsSection(context),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),
                SliverToBoxAdapter(
                  child: _buildBannerSection(context),
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: controller.refreshData,
                ),
                SliverToBoxAdapter(
                  child: _buildContentSections(context),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 60),
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: _buildLibraryCategoryBar(context),
                ),
                SliverToBoxAdapter(
                  child: _buildLibraryGenresSection(context),
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: () => controller.fetchLibraryMovies(isRefresh: true),
                ),
                ..._buildLibraryContentSlivers(context),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 60),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              if (controller.isSearching.value) {
                controller.clearSearch();
              } else {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  Get.offAllNamed('/main', arguments: {'initialIndex': 0});
                }
              }
            },
            child: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 20),
          ),
        ),
      ),
      title: Obx(() {
        if (controller.isSearching.value) {
          return Text(
            controller.searchQuery.value.isNotEmpty ? '搜索 · ${controller.searchQuery.value}' : '全网检索',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
              ],
            ),
          );
        }
        return Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopTabItem(title: '精选推荐', index: 0),
              _buildTopTabItem(title: '全量影库', index: 1),
            ],
          ),
        );
      }),
      actions: [
        // 避人脱敏模式切换
        Obx(() {
          final isSafe = JavSafeService.to.isSafeMode.value;
          return CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: JavSafeService.to.toggleSafeMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSafe
                    ? Colors.cyanAccent.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSafe
                      ? Colors.cyanAccent.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSafe ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                    color: isSafe ? Colors.cyanAccent : Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSafe ? '脱敏中' : '明文',
                    style: TextStyle(
                      color: isSafe ? Colors.cyanAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: () => _showServerConfigDialog(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
            ),
            child: const Icon(CupertinoIcons.gear_alt, color: Colors.cyanAccent, size: 16),
          ),
        ),
        // 一键速退按钮
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: Colors.redAccent.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            onPressed: controller.exitJav,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: Colors.redAccent, size: 14),
                SizedBox(width: 4),
                Text(
                  '一键速退',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabItem({required String title, required int index}) {
    return Obx(() {
      final isSelected = controller.currentMainTab.value == index;
      return GestureDetector(
        onTap: () => controller.switchMainTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyanAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF061815) : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSearchBarSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.search, color: Colors.white60, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller.searchInputController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '搜索番号、女优、剧情题材 (如 SSIS、三上悠亚)...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (val) => controller.executeSearch(val),
              ),
            ),
            Obx(() {
              if (controller.isSearching.value || controller.searchQuery.value.isNotEmpty) {
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: controller.clearSearch,
                  child: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white54, size: 18),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Obx(() {
      final tags = controller.recommendationTags;
      if (tags.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 32,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: tags.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final t = tags[index];
            final isCurrent = controller.searchQuery.value == t.prompt;
            return GestureDetector(
              onTap: () => controller.executeSearch(t.prompt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Colors.cyanAccent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? Colors.cyanAccent.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    t.name,
                    style: TextStyle(
                      color: isCurrent ? Colors.cyanAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  List<Widget> _buildSearchResultsSlivers(BuildContext context) {
    if (controller.isSearchLoading.value) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 16),
                SizedBox(height: 16),
                Text(
                  '🔮 本地大模型正在深度理解剧情诉求与黑话转译...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 6),
                Text(
                  '正在深入日文母库并发检索做种资源与精翻中字',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final items = controller.searchResults;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '精选结果 · 找到 ${items.length} 部真实作品',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: controller.clearSearch,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_counterclockwise, color: Colors.cyanAccent, size: 12),
                    SizedBox(width: 4),
                    Text('返回推荐', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (items.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.search, color: Colors.white24, size: 54),
                const SizedBox(height: 12),
                Text(
                  '未找到与 "${controller.searchQuery.value}" 相关的作品',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '可尝试直接搜索番号 (如 SSIS-834)、女优或核心题材',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 20),
                CupertinoButton(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  onPressed: controller.clearSearch,
                  child: const Text('返回推荐首页', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMovieGridCard(context, items[index]),
              childCount: items.length,
            ),
          ),
        ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 60),
      ),
    ];
  }

  Widget _buildMovieGridCard(BuildContext context, JavItem item) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (proxyCover.isNotEmpty)
                    JavSafeCover(
                      imageUrl: proxyCover,
                      code: item.code,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: Colors.black38,
                        child: const Center(
                          child: Icon(CupertinoIcons.photo, color: Colors.white38, size: 28),
                        ),
                      ),
                    )
                  else
                    Container(color: Colors.black38),
                  // 顶部番号标签
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.code,
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.hasSubtitles)
                          Container(
                            margin: const EdgeInsets.only(left: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('中字', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        if (item.isHd)
                          Container(
                            margin: const EdgeInsets.only(left: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  if (item.size != null && item.size!.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.size!,
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() {
                    final isSafe = JavSafeService.to.isSafeMode.value;
                    final displayTitle = isSafe
                        ? '${item.code} ${item.actress != null && item.actress!.isNotEmpty ? '· ${item.actress}' : ''}'
                        : item.title;
                    return Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.actress != null && item.actress!.isNotEmpty)
                        Expanded(
                          child: Text(
                            item.actress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.pinkAccent, fontSize: 10),
                          ),
                        )
                      else
                        Text(
                          item.date,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCategoryBar(BuildContext context) {
    return Obx(() {
      final currentCat = controller.libraryCategory.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.switchLibraryCategory('censored'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: currentCat == 'censored'
                          ? Colors.cyanAccent.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: currentCat == 'censored'
                          ? Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.square_grid_2x2_fill,
                            size: 14,
                            color: currentCat == 'censored' ? Colors.cyanAccent : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '有码影库 (Censored)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: currentCat == 'censored' ? FontWeight.bold : FontWeight.normal,
                              color: currentCat == 'censored' ? Colors.cyanAccent : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.switchLibraryCategory('uncensored'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: currentCat == 'uncensored'
                          ? Colors.pinkAccent.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: currentCat == 'uncensored'
                          ? Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 14,
                            color: currentCat == 'uncensored' ? Colors.pinkAccent : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '无码影库 (Uncensored)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: currentCat == 'uncensored' ? FontWeight.bold : FontWeight.normal,
                              color: currentCat == 'uncensored' ? Colors.pinkAccent : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLibraryGenresSection(BuildContext context) {
    return Obx(() {
      final genres = controller.libraryGenres;
      final selectedId = controller.selectedGenreId.value;

      return Container(
        height: 34,
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: genres.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final isAll = index == 0;
            final id = isAll ? 'all' : genres[index - 1].id;
            final name = isAll ? '全部题材' : genres[index - 1].name;
            final isSelected = selectedId == id;

            return GestureDetector(
              onTap: () => controller.selectLibraryGenre(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.cyanAccent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isSelected
                        ? Colors.cyanAccent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.cyanAccent : Colors.white70,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  List<Widget> _buildLibraryContentSlivers(BuildContext context) {
    if (controller.isLibraryLoading.value && controller.libraryMovies.isEmpty) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 14),
                SizedBox(height: 14),
                Text(
                  '正在深入母库检索全量影库片目...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final movies = controller.libraryMovies;
    if (movies.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.film, color: Colors.white24, size: 54),
                const SizedBox(height: 12),
                const Text(
                  '当前分类暂无作品数据',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  onPressed: () => controller.fetchLibraryMovies(isRefresh: true),
                  child: const Text('重新加载', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildMovieGridCard(context, movies[index]),
            childCount: movies.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: controller.isLibraryLoadingMore.value
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 10),
                      SizedBox(width: 8),
                      Text('正在加载更多影库作品...', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  )
                : Text(
                    controller.libraryHasMore.value ? '滑动加载更多' : '— 已浏览完全部片目 —',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _buildBannerSection(BuildContext context) {
    return Obx(() {
      final items = controller.bannerItems;
      if (items.isEmpty) {
        return const SizedBox(height: JavBannerCard.bannerHeight);
      }

      return SizedBox(
        height: JavBannerCard.bannerHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller.bannerPageController,
              itemCount: items.length,
              onPageChanged: (i) => controller.bannerPageIndex.value = i,
              itemBuilder: (context, index) {
                final item = items[index];
                return JavBannerCard(
                  item: item,
                  onTap: () => controller.openDetail(item.code),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Obx(() {
                final current = controller.bannerPageIndex.value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(items.length, (i) {
                    final active = i == current;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 12 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContentSections(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 今日最新发行 (有码)
        Obx(() {
          final items = controller.nowPlayingItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '今日最新发行',
            items: items,
            onMore: () => controller.navigateToCategory(
              title: '最新有码作品',
              categoryType: 'censored',
            ),
          );
        }),

        // 无码精选专区
        Obx(() {
          final items = controller.uncensoredItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '无码精选专区',
            items: items,
            onMore: () => controller.navigateToCategory(
              title: '无码精选作品',
              categoryType: 'uncensored',
            ),
          );
        }),

        // 人气爆款神作
        Obx(() {
          final items = controller.popularItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '人气爆款神作',
            items: items,
            onMore: () => controller.navigateToCategory(
              title: '最受欢迎高分榜',
              categoryType: 'popular',
            ),
          );
        }),

        // 热门精选推荐
        Obx(() {
          final items = controller.hotItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '热门精选推荐',
            items: items,
            onMore: () => controller.navigateToCategory(
              title: '热评高分精选',
              categoryType: 'hot',
            ),
          );
        }),

        // 精翻中文字幕
        Obx(() {
          final items = controller.subtitledItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '精翻中文字幕',
            items: items,
            onMore: () => controller.navigateToCategory(
              title: '精翻中文字幕',
              categoryType: 'subtitled',
            ),
          );
        }),

        // 精选女优专区
        Obx(() {
          final list = controller.actresses;
          if (list.isEmpty) return const SizedBox.shrink();
          return _buildActressesSection(context, list);
        }),
      ],
    );
  }

  Widget _buildHorizontalSection({
    required String title,
    required List<JavItem> items,
    VoidCallback? onMore,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 3.5,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (onMore != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onMore,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看更多',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: JavNowPlayingCard.cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return JavNowPlayingCard(
                  item: item,
                  onTap: () => controller.openDetail(item.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActressesSection(BuildContext context, List list) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '精选女优专区',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, color: Colors.cyanAccent, size: 14),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final a = list[index];
                final proxyAvatar = JavApiService().getProxyImageUrl(a.avatar);

                return GestureDetector(
                  onTap: () => controller.executeSearch(a.name),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.pinkAccent, Colors.purpleAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Obx(() {
                            final isSafe = JavSafeService.to.isSafeMode.value;
                            if (isSafe || proxyAvatar.isEmpty) {
                              return _buildActressAvatarPlaceholder(a.name);
                            }
                            return CachedImage(
                              imageUrl: proxyAvatar,
                              fit: BoxFit.cover,
                              errorWidget: _buildActressAvatarPlaceholder(a.name),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActressAvatarPlaceholder(String name) {
    final char = name.isNotEmpty ? name.substring(0, 1) : '优';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withValues(alpha: 0.8),
            Colors.pinkAccent.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    final textController = TextEditingController(text: controller.api.baseUrl);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('后端服务器配置'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '手机在 5G 移动网络下无法直接访问 192.168.50.x 局域网地址。请切换为家庭 Wi-Fi 或输入穿透/DDNS 域名。',
                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: textController,
                placeholder: 'http://192.168.50.81:8923',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('保存并重试'),
            onPressed: () {
              final newUrl = textController.text.trim();
              if (newUrl.isNotEmpty) {
                controller.updateServerUrl(newUrl);
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
