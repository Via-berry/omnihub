import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_detail_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_stills_gallery.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

class JavDetailPage extends GetView<JavDetailController> {
  const JavDetailPage({super.key});

  static const Color _themeColor = Color(0xFF061815);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeColor,
      extendBodyBehindAppBar: true,
      appBar: _buildTopAppBar(context),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
          );
        }

        final d = controller.detail.value;
        if (d == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  controller.errorMsg.value.isNotEmpty ? controller.errorMsg.value : '暂无番号详情数据',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  onPressed: controller.loadDetail,
                  child: const Text('重试', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeroBackdropSection(context, d),
            ),
            SliverToBoxAdapter(
              child: _buildActionButtons(context, d),
            ),
            SliverToBoxAdapter(
              child: _buildDetailContent(context, d),
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
            onPressed: () => Get.back(),
            child: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 20),
          ),
        ),
      ),
      actions: [
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

  Widget _buildHeroBackdropSection(BuildContext context, JavDetail detail) {
    final proxyCover = JavApiService().getProxyImageUrl(detail.cover, code: detail.code);

    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 巨幕全屏大图剧照
          proxyCover.isNotEmpty
              ? CachedImage(
                  imageUrl: proxyCover,
                  fit: BoxFit.cover,
                  errorWidget: Container(color: const Color(0xFF152220)),
                )
              : Container(color: const Color(0xFF152220)),

          // 渐变融色蒙层
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x1A061815),
                  Color(0x40061815),
                  Color(0xC0061815),
                  Color(0xFF061815),
                ],
                stops: [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),

          // 居中标题与徽章信息
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detail.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${detail.code} · ${detail.maker ?? detail.publisher ?? '独占企画'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildBadgeChip('★ 9.6', isScore: true),
                    if (detail.releaseDate != null && detail.releaseDate!.isNotEmpty)
                      _buildBadgeChip(detail.releaseDate!.split('-').first),
                    _buildBadgeChip('单体作品'),
                    if (detail.duration != null && detail.duration!.isNotEmpty)
                      _buildBadgeChip(detail.duration!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(String label, {bool isScore = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: isScore
            ? const Color(0xFFF5C518).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isScore
              ? const Color(0xFFF5C518).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isScore ? const Color(0xFFFFD66B) : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, JavDetail detail) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text(
                  '立即在线播放',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _openPlayModal(context, detail),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text(
                  '复制最佳磁链',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                onPressed: controller.copyBestMagnet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, JavDetail detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 简介与首发日期
          if (detail.releaseDate != null && detail.releaseDate!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.calendar, color: Colors.cyanAccent, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    '日本首发日期',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    detail.releaseDate!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 主演阵容
          if (detail.actresses.isNotEmpty) ...[
            _buildSectionHeader('主演阵容'),
            _buildActressesRow(detail.actresses),
            const SizedBox(height: 20),
          ],

          // 题材分类标签
          if (detail.genres.isNotEmpty) ...[
            _buildSectionHeader('题材分类标签'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.genres.map((g) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    g,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // 12 张高清剧照样张画廊 (大图展示)
          if (detail.samplePhotos.isNotEmpty) ...[
            _buildSectionHeader('官方高清剧照 (12 张画廊)'),
            JavStillsGallery(
              samplePhotos: detail.samplePhotos,
              code: detail.code,
            ),
            const SizedBox(height: 20),
          ],

          // 核心信息档案
          _buildSectionHeader('核心信息档案'),
          _buildCoreInfoCard(detail),
          const SizedBox(height: 20),

          // 磁力资源库 (纯复制磁链，完全无 transmission 推送)
          if (detail.magnets.isNotEmpty) ...[
            _buildSectionHeader('磁力资源库 (共 ${detail.magnets.length} 条可用)'),
            _buildMagnetList(detail.magnets),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF60A5FA), Color(0xFFF5C518)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActressesRow(List<JavActressRef> actresses) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actresses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = actresses[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent]),
                  ),
                  child: Center(
                    child: Text(
                      a.name.isNotEmpty ? a.name.characters.first : '女',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Text(
                      '专属演员',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoreInfoCard(JavDetail detail) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildInfoRow('番号识别码', detail.code),
          const Divider(color: Colors.white12, height: 16),
          _buildInfoRow('制作片商', detail.maker ?? '未知'),
          const Divider(color: Colors.white12, height: 16),
          _buildInfoRow('发行片商', detail.publisher ?? '未知'),
          if (detail.series != null && detail.series!.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 16),
            _buildInfoRow('企划系列', detail.series!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMagnetList(List<JavMagnet> magnets) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: magnets.take(5).length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final mag = magnets[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (mag.hasSubtitles)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('中字', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                  Expanded(
                    child: Text(
                      mag.name.isNotEmpty ? mag.name : detailTitle(mag),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mag.size,
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '发布: ${mag.date}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: Colors.cyan.shade800,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => controller.copyMagnet(mag),
                    child: const Text('复制磁链', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String detailTitle(JavMagnet mag) => '高清视频资源';

  void _openPlayModal(BuildContext context, JavDetail detail) {
    if (detail.onlineWatchUrls.isEmpty) {
      Get.snackbar('提示', '暂无在线播放直链，请使用磁力链接下载', backgroundColor: Colors.black87, colorText: Colors.white);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1F1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择播放线路',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ...detail.onlineWatchUrls.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.08),
                    leading: const Icon(Icons.play_circle_fill, color: Colors.cyanAccent),
                    title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      controller.openPlayer(entry.value);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
