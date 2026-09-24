import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_now_playing_card.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_safe_cover.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

class JavRecommendView extends StatelessWidget {
  const JavRecommendView({
    super.key,
    required this.controller,
    this.scrollController,
  });

  final JavController controller;
  final ScrollController? scrollController;

  static const double _bannerHeight = 450;
  static const Color _themeColor = Color(0xFF061815);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _themeColor,
      child: Stack(
        children: [
          CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: _bannerHeight,
                pinned: false,
                stretch: true,
                toolbarHeight: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Obx(() => _buildBanner(context)),
                ),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: controller.refreshData,
              ),
              SliverToBoxAdapter(
                child: _buildSections(context),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPadding + 4, left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  Get.offAllNamed('/main', arguments: {'initialIndex': 0});
                }
              },
              child: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 20),
            ),
          ),
          // 标题
          const Text(
            'Recommend',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
              ],
            ),
          ),
          // 右侧快捷功能
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 脱敏切换
              Obx(() {
                final isSafe = JavSafeService.to.isSafeMode.value;
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSafe
                        ? Colors.cyanAccent.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSafe
                          ? Colors.cyanAccent.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: JavSafeService.to.toggleSafeMode,
                    child: Icon(
                      isSafe ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                      color: isSafe ? Colors.cyanAccent : Colors.white70,
                      size: 16,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // 一键速退
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: controller.exitJav,
                  child: const Icon(CupertinoIcons.shield_fill, color: Colors.redAccent, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final items = controller.bannerItems;
    if (items.isEmpty) {
      return Container(
        color: _themeColor,
        child: const Center(child: CupertinoActivityIndicator(color: Colors.white70)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller.bannerPageController,
          itemCount: items.length,
          onPageChanged: (i) => controller.bannerPageIndex.value = i,
          itemBuilder: (context, index) {
            final item = items[index];
            final proxyCover = item.getProxyCover(controller.api.baseUrl);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (proxyCover.isNotEmpty)
                  JavSafeCover(
                    imageUrl: proxyCover,
                    code: item.code,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: const Color(0xFF061815)),
                  )
                else
                  Container(color: const Color(0xFF061815)),
                // 渐变遮罩
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 0.8, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        _themeColor.withValues(alpha: 0.85),
                        _themeColor,
                      ],
                    ),
                  ),
                ),
                // 底部影视信息与查看按钮
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.date.isNotEmpty) ...[
                        Text(
                          item.date.length >= 4 ? item.date.substring(0, 4) : item.date,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // 来源标签 + 番号
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 标题
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 磨砂玻璃“查看”按钮
                      SizedBox(
                        width: 180,
                        height: 38,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () => controller.openDetail(item.code),
                          child: const Text(
                            '查看',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        // 点状指示器
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Obx(() {
            final current = controller.bannerPageIndex.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSections(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 板块 1：今日最新发行（continueStyle）
        Obx(() {
          final items = controller.nowPlayingItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalCardSection(
            title: '今日最新发行',
            items: items,
            onMore: () => controller.navigateToCategory(title: '今日最新发行', categoryType: 'censored'),
          );
        }),

        // 板块 2：热门爆款神作（recommendStyle: 1大 + 2小）
        Obx(() {
          final items = controller.popularItems.isNotEmpty ? controller.popularItems : controller.hotItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildFeaturedStyleSection(
            context,
            title: '热门爆款推荐',
            items: items,
            onMore: () => controller.navigateToCategory(title: '最受欢迎高分榜', categoryType: 'popular'),
          );
        }),

        // 板块 3：无码精选专区（horizontalList）
        Obx(() {
          final items = controller.uncensoredItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalCardSection(
            title: '无码精选专区',
            items: items,
            onMore: () => controller.navigateToCategory(title: '无码精选作品', categoryType: 'uncensored'),
          );
        }),

        // 板块 4：精翻中文字幕（horizontalList）
        Obx(() {
          final items = controller.subtitledItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalCardSection(
            title: '精翻中文字幕',
            items: items,
            onMore: () => controller.navigateToCategory(title: '精翻中文字幕', categoryType: 'subtitled'),
          );
        }),

        // 板块 5：精选女优专区
        Obx(() {
          final list = controller.actresses;
          if (list.isEmpty) return const SizedBox.shrink();
          return _buildActressesSection(context, list);
        }),

        // 板块 6：MissAV 推荐题材流 (动态分段)
        Obx(() {
          final segments = controller.recombeeSegments;
          if (segments.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final seg in segments)
                if (seg.items.isNotEmpty)
                  _buildHorizontalCardSection(
                    title: '${seg.name} 精选',
                    items: seg.items,
                    onMore: () => controller.navigateToCategory(
                      title: '${seg.name} 精选专区',
                      categoryType: 'censored',
                      genre: seg.name,
                    ),
                  ),
            ],
          );
        }),
      ],
    );
  }

  // 水平滑动卡片栏（对标正在热映）
  Widget _buildHorizontalCardSection({
    required String title,
    required List<JavItem> items,
    VoidCallback? onMore,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
                ],
              ),
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

  // 1 大 + 2 小经典布局（对标热门电影）
  Widget _buildFeaturedStyleSection(
    BuildContext context, {
    required String title,
    required List<JavItem> items,
    VoidCallback? onMore,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final mainItem = items.first;
    final secondItem = items.length > 1 ? items[1] : null;
    final thirdItem = items.length > 2 ? items[2] : null;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onMore,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text('TOP', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 顶部大卡片
                _buildLargeFeaturedCard(context, mainItem, screenWidth - 32),
                if (secondItem != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMediumCard(context, secondItem),
                      ),
                      if (thirdItem != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMediumCard(context, thirdItem),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeFeaturedCard(BuildContext context, JavItem item, double width) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        width: width,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF10211F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (proxyCover.isNotEmpty)
              JavSafeCover(
                imageUrl: proxyCover,
                code: item.code,
                fit: BoxFit.cover,
                errorWidget: Container(color: const Color(0xFF10211F)),
              )
            else
              Container(color: const Color(0xFF10211F)),
            // 黑色下渐变
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 0.7, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          item.code,
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 3),
                      const Text(
                        '8.8',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Obx(() {
                    final isSafe = JavSafeService.to.isSafeMode.value;
                    final displayTitle = isSafe
                        ? '${item.code} ${item.actress != null ? '· ${item.actress}' : ''}'
                        : item.title;
                    return Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    );
                  }),
                  if (item.actress != null && item.actress!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.actress!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumCard(BuildContext context, JavItem item) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: const Color(0xFF10211F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (proxyCover.isNotEmpty)
              JavSafeCover(
                imageUrl: proxyCover,
                code: item.code,
                fit: BoxFit.cover,
                errorWidget: Container(color: const Color(0xFF10211F)),
              )
            else
              Container(color: const Color(0xFF10211F)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 0.75, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.code,
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 12),
                      const SizedBox(width: 2),
                      const Text(
                        '8.6',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Obx(() {
                    final isSafe = JavSafeService.to.isSafeMode.value;
                    final displayTitle = isSafe
                        ? '${item.code} ${item.actress != null ? '· ${item.actress}' : ''}'
                        : item.title;
                    return Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActressesSection(BuildContext context, List<JavActress> list) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Get.toNamed('/jav/actresses'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '热门女优',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
                ],
              ),
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
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Get.toNamed('/jav/category', arguments: {'title': '${a.name} 的作品', 'actress': a.name}),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
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
}
