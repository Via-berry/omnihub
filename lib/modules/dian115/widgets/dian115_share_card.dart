import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/controllers/dian115_share_controller.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/utils/open_url.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:moviepilot_mobile/utils/web_view_screen.dart';

class Dian115ShareCard extends StatefulWidget {
  const Dian115ShareCard({
    super.key,
    required this.item,
    required this.controller,
  });

  final Dian115ShareItem item;
  final Dian115ShareController controller;

  @override
  State<Dian115ShareCard> createState() => _Dian115ShareCardState();
}

class _Dian115ShareCardState extends State<Dian115ShareCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final service = Dian115Service.to;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：标题与渠道标志
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName.isNotEmpty ? item.fileName : '网盘分享资源',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.sharerName.isNotEmpty) ...[
                          Text(
                            '发布: ${item.sharerName}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          if (item.isVipSharer) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'VIP',
                                style: TextStyle(
                                  color: Color(0xFFFFC107),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                        ],
                        if (item.useCount > 0)
                          Text(
                            '热度 ${item.useCount} 次',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildChannelBadge(item),
            ],
          ),
          const SizedBox(height: 10),

          // 核心规格胶囊展示区 (Pills)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (item.resolution.isNotEmpty)
                _buildPill(
                  item.resolution.toUpperCase(),
                  bgColor: item.resolution.toUpperCase().contains('4K') ||
                          item.resolution.contains('2160')
                      ? const Color(0xFF10B981).withValues(alpha: 0.20)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.20),
                  textColor: item.resolution.toUpperCase().contains('4K') ||
                          item.resolution.contains('2160')
                      ? const Color(0xFF34D399)
                      : const Color(0xFF38BDF8),
                  borderColor: item.resolution.toUpperCase().contains('4K') ||
                          item.resolution.contains('2160')
                      ? const Color(0xFF10B981).withValues(alpha: 0.40)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.40),
                  isBold: true,
                ),
              if (item.source.isNotEmpty)
                _buildPill(
                  item.source,
                  bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                  textColor: const Color(0xFFA78BFA),
                  borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                ),
              if (item.videoCodec.isNotEmpty)
                _buildPill(
                  item.videoCodec,
                  bgColor: Colors.white.withValues(alpha: 0.08),
                  textColor: Colors.white.withValues(alpha: 0.85),
                ),
              if (item.hdr.isNotEmpty)
                _buildPill(
                  item.hdr,
                  bgColor: Colors.white.withValues(alpha: 0.08),
                  textColor: Colors.white.withValues(alpha: 0.85),
                ),
              if (item.audioCodec.isNotEmpty)
                _buildPill(
                  item.audioCodec,
                  bgColor: Colors.white.withValues(alpha: 0.08),
                  textColor: Colors.white.withValues(alpha: 0.85),
                ),
              if (item.hasChineseSubtitle)
                _buildPill(
                  '内封中字',
                  icon: CupertinoIcons.checkmark_alt,
                  bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                  textColor: const Color(0xFFFBBF24),
                  borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  isBold: true,
                ),
              if (item.episodeCount > 0)
                _buildPill(
                  '全 ${item.episodeCount} 集',
                  bgColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  textColor: const Color(0xFF22D3EE),
                ),
            ],
          ),

          // 分集列表抽屉 (Accordion)
          if (item.fileList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.folder_fill,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '包含 ${item.fileList.length} 个分集文件',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            _isExpanded ? '收起清单' : '展开清单',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _isExpanded
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isExpanded) ...[
                    const Divider(height: 10, color: Colors.white12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: item.fileList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final f = item.fileList[index];
                          return Row(
                            children: [
                              Icon(
                                CupertinoIcons.doc,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 10),

          // 底栏：文件体积与解锁/获取链接按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文件总容量',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.totalSizeHuman.isNotEmpty
                        ? item.totalSizeHuman
                        : '${(item.totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              // 解锁/获取链接与转存按钮区域
              Obx(() {
                final isUnlocked = service.isUnlocked(item.id);
                final cachedResult = service.getUnlockedInfo(item.id);

                if (isUnlocked && cachedResult != null && cachedResult.isSuccess) {
                  return Row(
                    children: [
                      // 查看/复制链接次级按钮
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        minSize: 30,
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        onPressed: () => _showLinkModal(context, cachedResult),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.link, size: 12, color: Colors.white70),
                            SizedBox(width: 3),
                            Text(
                              '链接',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 主转存按钮
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minSize: 32,
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(999),
                        onPressed: () {
                          widget.controller.transferToPan115(
                            shareUrl: cachedResult.shareUrl,
                            receiveCode: cachedResult.receiveCode,
                            magnetUrl: cachedResult.magnetUrl,
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.cloud_download_fill, size: 13, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              '转存',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // 未解锁状态或免费资源状态
                final isFree = item.unlockCost == 0;
                return Row(
                  children: [
                    Text(
                      !isFree ? '消耗 ${item.unlockCost} 积分' : '免费资源',
                      style: TextStyle(
                        color: !isFree
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minSize: 32,
                      color: isFree
                          ? const Color(0xFF10B981)
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                      onPressed: () => widget.controller.unlockAndTransfer(context, item),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFree
                                ? CupertinoIcons.cloud_download_fill
                                : CupertinoIcons.lock_fill,
                            size: 12,
                            color: isFree ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFree ? '转存' : '解锁并转存',
                            style: TextStyle(
                              color: isFree ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBadge(Dian115ShareItem item) {
    final is115 = item.is115;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: is115
            ? const Color(0xFF0284C7).withValues(alpha: 0.2)
            : const Color(0xFF9333EA).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: is115
              ? const Color(0xFF0284C7).withValues(alpha: 0.4)
              : const Color(0xFF9333EA).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        item.shareKindLabel.isNotEmpty
            ? item.shareKindLabel
            : (is115 ? '115网盘' : '离线磁力'),
        style: TextStyle(
          color: is115 ? const Color(0xFF38BDF8) : const Color(0xFFC084FC),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPill(
    String label, {
    IconData? icon,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndUnlock(BuildContext context) {
    final item = widget.item;
    final currentPoints = widget.controller.userPoints.value;

    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('确认解锁网盘资源'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '确认消耗 ${item.unlockCost} 积分获取此片源转存链接？',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前可用余额: $currentPoints 积分\n解锁后剩余: ${(currentPoints - item.unlockCost).clamp(0, 999999)} 积分',
                  style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                final res = await widget.controller.unlock(item);
                if (res != null && mounted) {
                  _showLinkModal(context, res);
                }
              },
              child: const Text('确认解锁'),
            ),
          ],
        );
      },
    );
  }

  void _showLinkModal(BuildContext context, Dian115UnlockResult result) {
    final has115 = result.shareUrl.isNotEmpty;
    final hasMagnet = result.magnetUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1B202B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF34D399), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '资源已就绪',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '已生成有效提取码与链接，支持永久转存',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (has115) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '115 分享链接:',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        result.shareUrl,
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '提取码:',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              result.receiveCode.isNotEmpty ? result.receiveCode : '免提取码',
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.controller.transferToPan115(
                        shareUrl: result.shareUrl,
                        receiveCode: result.receiveCode,
                        magnetUrl: result.magnetUrl,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.cloud_download_fill, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '一键转存至 115 ${Pan115Service.to.getTargetFolderName(widget.controller.mediaType)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      final textToCopy = '${result.shareUrl} 提取码: ${result.receiveCode}';
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      Navigator.of(ctx).pop();
                      ToastUtil.success('已复制 115 链接与提取码！');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          '一键复制 115 链接与提取码',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      WebUtil.open(url: result.shareUrl, internal: false);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.arrow_up_right_square, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '在 115 App 或浏览器中打开',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (hasMagnet) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '离线磁力链接:',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        result.magnetUrl,
                        style: const TextStyle(
                          color: Color(0xFFA78BFA),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.magnetUrl));
                      Navigator.of(ctx).pop();
                      ToastUtil.success('已复制磁力链接！');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.link, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '复制磁力链接',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
