import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/controllers/dian115_share_controller.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/widgets/dian115_login_sheet.dart';
import 'package:moviepilot_mobile/modules/dian115/widgets/dian115_share_card.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class Dian115ShareSheet extends StatefulWidget {
  const Dian115ShareSheet({
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
      builder: (_) => Dian115ShareSheet(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        mediaTitle: mediaTitle,
      ),
    );
  }

  @override
  State<Dian115ShareSheet> createState() => _Dian115ShareSheetState();
}

class _Dian115ShareSheetState extends State<Dian115ShareSheet> {
  late final Dian115ShareController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      Dian115ShareController(
        tmdbId: widget.tmdbId,
        mediaType: widget.mediaType,
        initialSeason: widget.season,
        mediaTitle: widget.mediaTitle,
      ),
      tag: '${widget.tmdbId}_${widget.season}_${widget.mediaTitle}',
    );
  }

  @override
  void dispose() {
    Get.delete<Dian115ShareController>(
      tag: '${widget.tmdbId}_${widget.season}_${widget.mediaTitle}',
    );
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
          _buildAuthBanner(context),
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildAuthBanner(BuildContext context) {
    return Obx(() {
      if (controller.isOnline.value && !controller.isAuthenticated.value) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '癫影网关登录凭证已过期，点击快速续期',
                  style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(6),
                minSize: 24,
                onPressed: () async {
                  final ok = await Dian115LoginSheet.show(context);
                  if (ok == true) {
                    controller.onReauthenticated();
                  }
                },
                child: const Text(
                  '一键续期',
                  style: TextStyle(color: Color(0xFF11151F), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C26),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          // 拖拽指示条
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
          const SizedBox(height: 10),

          // 第一行：标题、资源数量与操作控制（设置与关闭）
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.cloud_download,
                  color: Color(0xFF34D399),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '癫影 115 资源',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '共 ${controller.allShares.length} 个',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
              const Spacer(),
              // 设置按钮（齿轮）
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 30,
                onPressed: () => _showConfigDialog(context),
                child: Icon(
                  CupertinoIcons.gear_alt,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              // 关闭按钮
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.clear, size: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 第二行：片源标识/网关状态 与 真实积分徽章/真实签到按钮
          Row(
            children: [
              if (widget.tmdbId != null && widget.tmdbId! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'TMDB ${widget.tmdbId}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (widget.mediaTitle.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.mediaTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 8),

              Obx(() {
                final online = controller.isOnline.value;
                return Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF10B981)
                            : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      online ? '网关在线' : '离线探测',
                      style: TextStyle(
                        color: online
                            ? const Color(0xFF34D399)
                            : Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),

              const Spacer(),

              // 真实积分展示
              Obx(() {
                if (!controller.isAuthenticated.value) {
                  return GestureDetector(
                    onTap: () async {
                      final ok = await Dian115LoginSheet.show(context);
                      if (ok == true) {
                        controller.onReauthenticated();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⚠️', style: TextStyle(fontSize: 10)),
                          SizedBox(width: 3),
                          Text(
                            '凭证失效',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text(
                        '${controller.userPoints.value}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 1),
                      const Text(
                        '分',
                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(width: 8),

              // 签到按钮：今日已签置灰不可点，未签可点签到+5
              Obx(() {
                if (!controller.isAuthenticated.value) {
                  return const SizedBox.shrink();
                }
                final isSigned = controller.isTodaySigned.value;
                final isSigningIn = controller.isSigningIn.value;

                if (isSigned) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark_alt, size: 11, color: Colors.white38),
                        SizedBox(width: 2),
                        Text(
                          '今日已签',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minSize: 26,
                  color: const Color(0xFF10B981).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: isSigningIn ? null : controller.signin,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.sparkles, size: 11, color: Color(0xFF34D399)),
                      const SizedBox(width: 3),
                      Text(
                        isSigningIn ? '签到中...' : '签到+5',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Obx(() {
      final seasons = controller.sharesResponse.value?.availableSeasons ?? const [];
      final hasSeasons = seasons.length > 1;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 季度选择胶囊 (剧集)
              if (hasSeasons) ...[
                _buildFilterChip(
                  label: '全部季度',
                  isSelected: controller.filterSeason.value == -1,
                  onTap: () {
                    controller.filterSeason.value = -1;
                    controller.fetchShares();
                  },
                ),
                for (final s in seasons) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: s.season == 0 ? '特别篇' : '第 ${s.season} 季',
                    count: s.shareCount,
                    isSelected: controller.filterSeason.value == s.season,
                    onTap: () {
                      controller.filterSeason.value = s.season;
                      controller.fetchShares();
                    },
                  ),
                ],
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: Colors.white12),
                const SizedBox(width: 10),
              ],

              // 分辨率胶囊
              _buildFilterChip(
                label: '全部清晰度',
                isSelected: controller.filterResolution.value == 'all',
                onTap: () => controller.filterResolution.value = 'all',
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '4K UHD',
                isSelected: controller.filterResolution.value == '4K',
                onTap: () => controller.filterResolution.value =
                    controller.filterResolution.value == '4K' ? 'all' : '4K',
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '1080P',
                isSelected: controller.filterResolution.value == '1080P',
                onTap: () => controller.filterResolution.value =
                    controller.filterResolution.value == '1080P' ? 'all' : '1080P',
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: Colors.white12),
              const SizedBox(width: 10),

              // 中文字幕
              _buildFilterChip(
                label: '仅含中字',
                icon: CupertinoIcons.captions_bubble_fill,
                isSelected: controller.filterOnlyChineseSub.value,
                activeColor: const Color(0xFFF59E0B),
                onTap: () => controller.filterOnlyChineseSub.toggle(),
              ),
              const SizedBox(width: 6),

              // 渠道类型
              _buildFilterChip(
                label: '仅115网盘',
                isSelected: controller.filterKind.value == '115',
                onTap: () => controller.filterKind.value =
                    controller.filterKind.value == '115' ? 'all' : '115',
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '仅离线磁力',
                isSelected: controller.filterKind.value == 'offline',
                onTap: () => controller.filterKind.value =
                    controller.filterKind.value == 'offline' ? 'all' : 'offline',
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: Colors.white12),
              const SizedBox(width: 10),

              // 排序模式切换
              _buildFilterChip(
                label: controller.sortBy.value == 'size_desc'
                    ? '体积从大到小 ↓'
                    : (controller.sortBy.value == 'use_desc'
                        ? '热度最高'
                        : '最新发布'),
                icon: CupertinoIcons.sort_down,
                isSelected: true,
                activeColor: const Color(0xFF3B82F6),
                onTap: () {
                  if (controller.sortBy.value == 'size_desc') {
                    controller.sortBy.value = 'use_desc';
                  } else if (controller.sortBy.value == 'use_desc') {
                    controller.sortBy.value = 'date_desc';
                  } else {
                    controller.sortBy.value = 'size_desc';
                  }
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFilterChip({
    required String label,
    int? count,
    IconData? icon,
    required bool isSelected,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final effectiveColor = activeColor ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 11,
                color: isSelected ? effectiveColor : Colors.white60,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? effectiveColor : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 3),
              Text(
                '($count)',
                style: TextStyle(
                  color: isSelected ? effectiveColor.withValues(alpha: 0.8) : Colors.white38,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(color: Colors.white, radius: 14),
              const SizedBox(height: 12),
              Text(
                '正在检索癫影 115 资源...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      if (controller.errorMsg.value.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.amber,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  controller.errorMsg.value,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  onPressed: controller.fetchShares,
                  child: const Text('重新加载', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      }

      final list = controller.filteredShares;
      if (list.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.tray,
                color: Colors.white24,
                size: 48,
              ),
              const SizedBox(height: 10),
              const Text(
                '暂无符合当前筛选条件的网盘资源',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
                onPressed: () {
                  controller.filterResolution.value = 'all';
                  controller.filterKind.value = 'all';
                  controller.filterOnlyChineseSub.value = false;
                  controller.filterSeason.value = -1;
                },
                child: const Text('重置筛选', style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          return Dian115ShareCard(item: item, controller: controller);
        },
      );
    });
  }

  void _showConfigDialog(BuildContext context) {
    final hostController = TextEditingController(text: Dian115Service.to.host.value);
    final movieCidController = TextEditingController(text: Pan115Service.to.movieCid.value);
    final tvCidController = TextEditingController(text: Pan115Service.to.tvCid.value);
    final cookieController = TextEditingController(text: Pan115Service.to.cookie.value);

    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('配置网关与 115 转存参数'),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '癫影中转网关地址:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  CupertinoTextField(
                    controller: hostController,
                    placeholder: '如 http://192.168.50.81:8924',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '115 电影保存目录 CID:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  CupertinoTextField(
                    controller: movieCidController,
                    placeholder: '默认 3374319270869599334',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '115 电视剧保存目录 CID:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  CupertinoTextField(
                    controller: tvCidController,
                    placeholder: '默认 3374342216908539463',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '115 用户账号 Cookie:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  CupertinoTextField(
                    controller: cookieController,
                    maxLines: 3,
                    placeholder: 'UID=...; CID=...; SEID=...; KID=...',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final newHost = hostController.text.trim();
                final newMovieCid = movieCidController.text.trim();
                final newTvCid = tvCidController.text.trim();
                final newCookie = cookieController.text.trim();

                if (newHost.isNotEmpty) {
                  await Dian115Service.to.updateHost(newHost);
                }
                await Pan115Service.to.updateConfig(
                  newMovieCid: newMovieCid.isNotEmpty ? newMovieCid : null,
                  newTvCid: newTvCid.isNotEmpty ? newTvCid : null,
                  newCookie: newCookie.isNotEmpty ? newCookie : null,
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                controller.fetchShares();
                ToastUtil.success('已保存配置并刷新');
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
