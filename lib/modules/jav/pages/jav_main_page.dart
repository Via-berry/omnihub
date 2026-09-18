import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_discover_view.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_recommend_view.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_safe_cover.dart';

class JavMainPage extends GetView<JavController> {
  const JavMainPage({super.key});

  static const Color _themeColor = Color(0xFF061815);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeColor,
      body: Obx(() {
        if (controller.isLoading.value && controller.bannerItems.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
          );
        }

        if (controller.errorMsg.value.isNotEmpty && controller.bannerItems.isEmpty) {
          return _buildErrorState(context);
        }

        return Stack(
          children: [
            // 主视图内容
            IndexedStack(
              index: controller.isSearching.value ? 2 : controller.currentMainTab.value,
              children: [
                JavRecommendView(controller: controller),
                JavDiscoverView(controller: controller),
                _buildSearchView(context),
              ],
            ),
            // 底部磨砂玻璃悬浮导航 Dock 栏
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: _buildBottomFloatingDock(context),
              ),
            ),
          ],
        );
      }),
    );
  }

  // 底部磨砂玻璃悬浮 Dock 栏（对标 OmniHub 底部导航）
  Widget _buildBottomFloatingDock(BuildContext context) {
    return Obx(() {
      final isSearching = controller.isSearching.value;
      final currentTab = controller.currentMainTab.value;

      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2522).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDockItem(
              icon: Icons.movie_outlined,
              selectedIcon: Icons.movie_rounded,
              label: '推荐',
              isSelected: !isSearching && currentTab == 0,
              onTap: () {
                if (isSearching) controller.clearSearch();
                controller.switchMainTab(0);
              },
            ),
            const SizedBox(width: 4),
            _buildDockItem(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore_rounded,
              label: '探索',
              isSelected: !isSearching && currentTab == 1,
              onTap: () {
                if (isSearching) controller.clearSearch();
                controller.switchMainTab(1);
              },
            ),
            const SizedBox(width: 4),
            _buildDockItem(
              icon: Icons.search_rounded,
              selectedIcon: Icons.search_rounded,
              label: '搜索',
              isSelected: isSearching,
              onTap: () {
                if (!isSearching) {
                  controller.isSearching.value = true;
                }
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDockItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: isSelected ? Border.all(color: Colors.cyanAccent.withValues(alpha: 0.6)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 18,
              color: isSelected ? Colors.cyanAccent : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.cyanAccent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 搜索全屏视图
  Widget _buildSearchView(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _themeColor,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 搜索顶栏
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: topPadding + 10, left: 16, right: 16, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.search, color: Colors.cyanAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controller.searchInputController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '搜索番号、女优、剧情题材...',
                                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (val) => controller.executeSearch(val),
                              ),
                            ),
                            if (controller.searchInputController.text.isNotEmpty)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () {
                                  controller.searchInputController.clear();
                                  controller.searchQuery.value = '';
                                },
                                child: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white54, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: controller.clearSearch,
                      child: const Text('取消', style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            // 推荐题材标签
            SliverToBoxAdapter(
              child: _buildPromptTags(context),
            ),
            // 搜索结果列表或状态
            ..._buildSearchResultsSlivers(context),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTags(BuildContext context) {
    return Obx(() {
      final tags = controller.recommendationTags;
      if (tags.isEmpty) return const SizedBox.shrink();
      return Container(
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: tags.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final t = tags[index];
            return GestureDetector(
              onTap: () => controller.executeSearch(t.prompt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Text(
                    t.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
    return [
      Obx(() {
        if (controller.isSearchLoading.value) {
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 16),
                  SizedBox(height: 16),
                  Text('正在深入母库检索片源与中字...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        final items = controller.searchResults;
        if (controller.searchQuery.value.isNotEmpty && items.isEmpty) {
          return SliverFillRemaining(
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
                    '可尝试直接输入番号 (如 SSIS-834) 或核心题材',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSearchResultCard(context, items[index]),
              childCount: items.length,
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildSearchResultCard(BuildContext context, JavItem item) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10211F),
          borderRadius: BorderRadius.circular(14),
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
                      errorWidget: Container(color: Colors.black26),
                    )
                  else
                    Container(color: Colors.black26),
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
                  if (item.hasSubtitles || item.isHd)
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
                        ? '${item.code} ${item.actress != null ? '· ${item.actress}' : ''}'
                        : item.title;
                    return Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
                    );
                  }),
                  const SizedBox(height: 4),
                  if (item.actress != null && item.actress!.isNotEmpty)
                    Text(
                      item.actress!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 10),
                    )
                  else
                    Text(item.date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
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
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                borderRadius: BorderRadius.circular(12),
                onPressed: controller.refreshData,
                child: const Text('重试连接', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
