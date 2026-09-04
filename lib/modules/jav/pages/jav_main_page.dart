import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_banner_card.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_now_playing_card.dart';
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

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
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
          ],
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
      title: const Text(
        'Recommend',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showServerConfigDialog(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: Icon(CupertinoIcons.gear_alt, color: Colors.cyanAccent, size: 18),
            ),
          ),
        ),
      ),
      actions: [
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
        // 今日最新发行
        Obx(() {
          final items = controller.nowPlayingItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '今日最新发行',
            items: items,
          );
        }),

        // 热门高分神作
        Obx(() {
          final items = controller.hotItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '热门精选推荐',
            items: items,
          );
        }),

        // 中文字幕精选
        Obx(() {
          final items = controller.subtitledItems;
          if (items.isEmpty) return const SizedBox.shrink();
          return _buildHorizontalSection(
            title: '精翻中文字幕',
            items: items,
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
    required List items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.chevron_right, color: Colors.cyanAccent, size: 14),
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
                  onTap: () {
                    // 筛选女优作品
                  },
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
                          child: proxyAvatar.isNotEmpty
                              ? CachedImage(
                                  imageUrl: proxyAvatar,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: Colors.black45,
                                    child: const Center(
                                      child: Icon(Icons.person, color: Colors.white54, size: 24),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.black54,
                                  child: const Center(
                                    child: Icon(Icons.person, color: Colors.white54, size: 24),
                                  ),
                                ),
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
