import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/pansou/controllers/pansou_share_controller.dart';
import 'package:moviepilot_mobile/modules/pansou/models/pansou_models.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

class PansouShareCard extends StatefulWidget {
  const PansouShareCard({
    super.key,
    required this.item,
    required this.controller,
  });

  final PansouItem item;
  final PansouShareController controller;

  @override
  State<PansouShareCard> createState() => _PansouShareCardState();
}

class _PansouShareCardState extends State<PansouShareCard> {
  bool _isExpanded = false;

  void _copyToClipboard(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    ToastUtil.success(tip);
  }

  void _copyFullShareInfo() {
    final item = widget.item;
    final sb = StringBuffer();
    sb.writeln(item.title);
    sb.writeln(item.url);
    if (item.password.isNotEmpty) {
      sb.writeln('提取码: ${item.password}');
    }
    _copyToClipboard(sb.toString().trim(), '资源信息与链接已复制');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
          // 头部：标题与网盘类型标签
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isNotEmpty ? item.title : '未知资源',
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
                        if (item.source.isNotEmpty) ...[
                          Text(
                            '渠道: ${item.source}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.datetime.isNotEmpty)
                          Text(
                            item.datetime.length > 10
                                ? item.datetime.substring(0, 10)
                                : item.datetime,
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
              _buildTypeBadge(item),
            ],
          ),
          const SizedBox(height: 10),

          // 核心规格胶囊展示区
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (item.resolution.isNotEmpty)
                _buildPill(
                  item.resolution,
                  bgColor: item.resolution == '4K'
                      ? const Color(0xFF10B981).withValues(alpha: 0.20)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.20),
                  textColor: item.resolution == '4K'
                      ? const Color(0xFF34D399)
                      : const Color(0xFF38BDF8),
                  borderColor: item.resolution == '4K'
                      ? const Color(0xFF10B981).withValues(alpha: 0.40)
                      : const Color(0xFF0EA5E9).withValues(alpha: 0.40),
                  isBold: true,
                ),
              if (item.hdr.isNotEmpty)
                _buildPill(
                  item.hdr,
                  bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                  textColor: const Color(0xFFFBBF24),
                  borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  isBold: true,
                ),
              if (item.videoCodec.isNotEmpty)
                _buildPill(
                  item.videoCodec,
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
                  bgColor: const Color(0xFFEC4899).withValues(alpha: 0.18),
                  textColor: const Color(0xFFF472B6),
                  borderColor: const Color(0xFFEC4899).withValues(alpha: 0.35),
                  isBold: true,
                ),
              if (item.season > 0)
                _buildPill(
                  '第 ${item.season} 季',
                  bgColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  textColor: const Color(0xFF22D3EE),
                ),
              if (item.totalSizeHuman.isNotEmpty)
                _buildPill(
                  item.totalSizeHuman,
                  bgColor: Colors.white.withValues(alpha: 0.06),
                  textColor: Colors.white.withValues(alpha: 0.7),
                ),
            ],
          ),

          // 展开内容详情抽屉
          if (item.note.isNotEmpty || item.images.isNotEmpty) ...[
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
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.text_quote,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '资源描述与预览信息',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            _isExpanded ? '收起' : '展开详情',
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
                    if (item.images.isNotEmpty) ...[
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedImage(
                                imageUrl: item.images[index],
                                width: 120,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      item.note,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        height: 1.4,
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

          // 底栏：提取码/特征码与操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 提取码或特征码胶囊
              if (item.is115 && item.password.isNotEmpty)
                InkWell(
                  onTap: () => _copyToClipboard(item.password, '提取码已复制'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.lock_shield_fill,
                            size: 11, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 4),
                        Text(
                          '码: ${item.password}',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (item.isOfflineDownload)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.arrow_down_circle_fill,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        item.isMagnet ? '磁力离线' : '电驴离线',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),

              // 右侧操作区：复制与一键转存
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: const Size(0, 30),
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    onPressed: _copyFullShareInfo,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.link, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '复制',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  Obx(() {
                    final isBusy =
                        widget.controller.isTransferring[item.uniqueId] == true;
                    final isDone =
                        widget.controller.transferredMap[item.uniqueId] == true;

                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 32),
                      color: isDone ? const Color(0xFF059669) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(999),
                      onPressed: isBusy
                          ? null
                          : () => widget.controller.transferToPan115(
                                context: context,
                                item: item,
                              ),
                      child: isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CupertinoActivityIndicator(
                                radius: 7,
                                color: Colors.black,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDone
                                      ? CupertinoIcons.checkmark_alt
                                      : CupertinoIcons.cloud_download_fill,
                                  size: 13,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDone ? '已转存' : '一键转存',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
        ],
      ),
    );
  }

  Widget _buildTypeBadge(PansouItem item) {
    Color color;
    IconData icon;
    String label = item.type.label;

    switch (item.type) {
      case PansouItemType.pan115:
        color = const Color(0xFF00E5FF);
        icon = CupertinoIcons.cloud_fill;
        break;
      case PansouItemType.magnet:
        color = const Color(0xFFA855F7);
        icon = CupertinoIcons.bolt_horizontal_circle_fill;
        break;
      case PansouItemType.ed2k:
        color = const Color(0xFFF59E0B);
        icon = CupertinoIcons.arrow_2_circlepath_circle_fill;
        break;
      case PansouItemType.other:
        color = Colors.white54;
        icon = CupertinoIcons.doc_fill;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    String label, {
    Color? bgColor,
    Color? textColor,
    Color? borderColor,
    IconData? icon,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null ? Border.all(color: borderColor, width: 0.8) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor ?? Colors.white70),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white70,
              fontSize: 10,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
