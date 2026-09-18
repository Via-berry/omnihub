import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_safe_cover.dart';

class JavDiscoverView extends StatelessWidget {
  const JavDiscoverView({
    super.key,
    required this.controller,
    this.scrollController,
  });

  final JavController controller;
  final ScrollController? scrollController;

  static const Color _themeColor = Color(0xFF061815);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _themeColor,
      child: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 260) {
                  controller.loadMoreLibraryMovies();
                }
                return false;
              },
              child: CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () => controller.fetchLibraryMovies(isRefresh: true),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildSourceChipsBar(context),
              ),
            ),
            Obx(() {
              if (controller.isLibraryLoading.value && controller.libraryMovies.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 14),
                        SizedBox(height: 14),
                        Text(
                          '正在连接母库检索片目...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final movies = controller.libraryMovies;
              if (movies.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.film, color: Colors.white24, size: 54),
                        const SizedBox(height: 12),
                        const Text(
                          '当前分类暂无匹配作品',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          onPressed: () => controller.fetchLibraryMovies(isRefresh: true),
                          child: const Text('重试加载', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final hero = movies.first;
              final rest = movies.length > 1 ? movies.sublist(1) : <JavItem>[];

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 顶部焦点大卡片
                    _buildFeaturedCard(context, hero),
                    const SizedBox(height: 20),
                    // 分界头
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '全部片源',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '已载入 ${movies.length} 部作品',
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 纵向行卡片列表
                    for (int i = 0; i < rest.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _buildMediaRowCard(context, rest[i]),
                    ],
                    // 底部加载更多指示器
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: controller.isLibraryLoadingMore.value
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 10),
                                  SizedBox(width: 8),
                                  Text('正在翻页加载母库作品...', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                ],
                              )
                            : Text(
                                controller.libraryHasMore.value ? '滑动自动加载下一页' : '— 已加载全部作品 —',
                                style: const TextStyle(color: Colors.white30, fontSize: 11),
                              ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  ],
),
);
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _themeColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: Container(
        margin: const EdgeInsets.all(8),
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
      title: const Text(
        '探索',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // 题材筛选抽屉入口
        IconButton(
          tooltip: '题材筛选',
          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          onPressed: () => _openFilterSheet(context),
        ),
        // 脱敏切换
        Obx(() {
          final isSafe = JavSafeService.to.isSafeMode.value;
          return IconButton(
            tooltip: '脱敏模式',
            icon: Icon(
              isSafe ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
              color: isSafe ? Colors.cyanAccent : Colors.white70,
              size: 20,
            ),
            onPressed: JavSafeService.to.toggleSafeMode,
          );
        }),
        // 一键速退
        IconButton(
          tooltip: '一键速退',
          icon: const Icon(CupertinoIcons.shield_fill, color: Colors.redAccent, size: 20),
          onPressed: controller.exitJav,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // 来源切换胶囊栏（有码全库、无码全库、人气排行、精翻中字）
  Widget _buildSourceChipsBar(BuildContext context) {
    final sources = [
      {'key': 'censored', 'label': 'JavBus 有码', 'color': Colors.cyanAccent, 'icon': Icons.grid_view_rounded},
      {'key': 'uncensored', 'label': 'JavBus 无码', 'color': Colors.pinkAccent, 'icon': Icons.stars_rounded},
      {'key': 'popular', 'label': '人气排行', 'color': Colors.amberAccent, 'icon': Icons.local_fire_department_rounded},
      {'key': 'subtitled', 'label': '精翻中字', 'color': Colors.deepOrangeAccent, 'icon': Icons.subtitles_rounded},
    ];

    return Obx(() {
      final current = controller.libraryCategory.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < sources.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _buildSourceChip(
                label: sources[i]['label'] as String,
                color: sources[i]['color'] as Color,
                icon: sources[i]['icon'] as IconData,
                selected: current == sources[i]['key'],
                onTap: () => controller.switchLibraryCategory(sources[i]['key'] as String),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildSourceChip({
    required String label,
    required Color color,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 38,
        padding: const EdgeInsets.fromLTRB(5, 4, 14, 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: selected ? color : Colors.white70, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 顶部焦点精选大卡片（对标 _FeaturedCard）
  Widget _buildFeaturedCard(BuildContext context, JavItem item) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF10211F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
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
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.2, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
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
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          item.code,
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 3),
                      const Text(
                        '8.7',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final isSafe = JavSafeService.to.isSafeMode.value;
                    final displayTitle = isSafe
                        ? '${item.code} ${item.actress != null ? '· ${item.actress}' : ''}'
                        : item.title;
                    return Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    );
                  }),
                  if (item.actress != null && item.actress!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${item.actress!} · ${item.date}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12),
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

  // 横向行卡片（对标 _MediaRowCard）
  Widget _buildMediaRowCard(BuildContext context, JavItem item) {
    final proxyCover = item.getProxyCover(controller.api.baseUrl);
    return GestureDetector(
      onTap: () => controller.openDetail(item.code),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF10211F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧封面海报
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 114,
                child: proxyCover.isNotEmpty
                    ? JavSafeCover(
                        imageUrl: proxyCover,
                        code: item.code,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: Colors.black26,
                          child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.white24, size: 24)),
                        ),
                      )
                    : Container(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧信息栏
            Expanded(
              child: SizedBox(
                height: 114,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.code,
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (item.hasSubtitles) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('中字', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (item.isHd) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            const Spacer(),
                            if (item.date.isNotEmpty)
                              Text(
                                item.date,
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          );
                        }),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item.actress != null && item.actress!.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.actress!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Colors.amberAccent, size: 12),
                            SizedBox(width: 2),
                            Text('8.7', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 题材筛选抽屉
  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF0D2522),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 顶栏拖动条
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '题材分类筛选',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      child: const Text('重置全部', style: TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                      onPressed: () {
                        controller.selectLibraryGenre('all');
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: Obx(() {
                  final genres = controller.libraryGenres;
                  final selectedId = controller.selectedGenreId.value;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        _buildGenreTagChip(
                          label: '全部题材',
                          isSelected: selectedId == 'all',
                          onTap: () {
                            controller.selectLibraryGenre('all');
                            Navigator.of(ctx).pop();
                          },
                        ),
                        for (final g in genres.where((item) => item.id != 'all'))
                          _buildGenreTagChip(
                            label: g.name,
                            isSelected: selectedId == g.id,
                            onTap: () {
                              controller.selectLibraryGenre(g.id);
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenreTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
