import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/pansou/controllers/pansou_share_controller.dart';
import 'package:moviepilot_mobile/modules/pansou/widgets/pansou_settings_sheet.dart';
import 'package:moviepilot_mobile/modules/pansou/widgets/pansou_share_card.dart';
import 'package:moviepilot_mobile/widgets/app_loading.dart';

class PansouShareSheet extends StatefulWidget {
  const PansouShareSheet({
    super.key,
    this.tmdbId,
    this.mediaType = 'movie',
    this.season,
    this.mediaTitle = '',
  });

  final int? tmdbId;
  final String mediaType;
  final int? season;
  final String mediaTitle;

  static Future<void> show(
    BuildContext context, {
    int? tmdbId,
    String mediaType = 'movie',
    int? season,
    String mediaTitle = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PansouShareSheet(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        mediaTitle: mediaTitle,
      ),
    );
  }

  @override
  State<PansouShareSheet> createState() => _PansouShareSheetState();
}

class _PansouShareSheetState extends State<PansouShareSheet> {
  late final PansouShareController controller;
  late final TextEditingController _kwController;

  @override
  void initState() {
    super.initState();
    final tag = 'pansou_${widget.tmdbId}_${widget.season}_${widget.mediaTitle}';
    controller = Get.put(
      PansouShareController(
        tmdbId: widget.tmdbId,
        mediaType: widget.mediaType,
        initialSeason: widget.season,
        mediaTitle: widget.mediaTitle,
      ),
      tag: tag,
    );
    _kwController = TextEditingController(text: controller.searchKeyword.value);
  }

  @override
  void dispose() {
    _kwController.dispose();
    final tag = 'pansou_${widget.tmdbId}_${widget.season}_${widget.mediaTitle}';
    Get.delete<PansouShareController>(tag: tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF11151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildSearchBar(context),
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161C26),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.search_circle_fill,
                  size: 20,
                  color: Color(0xFF11151F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PanSou 网盘聚合',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '直转 115',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已聚合 115 分享、磁力与电驴资源',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () => PansouSettingsSheet.show(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.clear,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, size: 16, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _kwController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '输入搜索关键词...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (val) {
                        controller.updateKeyword(val);
                      },
                    ),
                  ),
                  if (_kwController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _kwController.clear();
                      },
                      child: const Icon(CupertinoIcons.clear_circled_solid,
                          size: 14, color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, 38),
            color: const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(12),
            onPressed: () {
              controller.updateKeyword(_kwController.text);
            },
            child: const Text(
              '搜索',
              style: TextStyle(
                color: Color(0xFF11151F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Obx(() {
      final activeFilter = controller.selectedFilter.value;
      final total = controller.items.length;
      final count115 = controller.count115;
      final countMagnet = controller.countMagnet;
      final count4k = controller.count4k;

      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildFilterPill('全部', 'all', total, activeFilter == 'all'),
            const SizedBox(width: 8),
            _buildFilterPill('115 网盘', '115', count115, activeFilter == '115'),
            const SizedBox(width: 8),
            _buildFilterPill('磁力/电驴', 'magnet', countMagnet, activeFilter == 'magnet'),
            const SizedBox(width: 8),
            _buildFilterPill('4K 专区', '4k', count4k, activeFilter == '4k'),
          ],
        ),
      );
    });
  }

  Widget _buildFilterPill(String title, String key, int count, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.setFilter(key),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoading(size: 80),
              SizedBox(height: 12),
              Text(
                '正在并发检索 PanSou 资源...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        );
      }

      if (controller.errorMessage.value.isNotEmpty && controller.items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.search, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage.value,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => controller.fetchResults(refresh: true),
                child: const Text(
                  '重试搜索',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }

      final displayItems = controller.filteredItems;

      if (displayItems.isEmpty) {
        return const Center(
          child: Text(
            '当前筛选下暂无结果',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: displayItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = displayItems[index];
          return PansouShareCard(
            item: item,
            controller: controller,
          );
        },
      );
    });
  }
}
