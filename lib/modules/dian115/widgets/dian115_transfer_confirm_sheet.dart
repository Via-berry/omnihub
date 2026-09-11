import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';

/// 115 转存确认与目标目录选择弹窗
class Dian115TransferConfirmSheet extends StatefulWidget {
  const Dian115TransferConfirmSheet({
    super.key,
    required this.item,
    required this.mediaType,
    required this.mediaTitle,
    required this.userPoints,
    required this.isUnlock,
  });

  final Dian115ShareItem item;
  final String mediaType;
  final String mediaTitle;
  final int userPoints;
  final bool isUnlock;

  static Future<({String cid, String folderName})?> show(
    BuildContext context, {
    required Dian115ShareItem item,
    required String mediaType,
    required String mediaTitle,
    required int userPoints,
    required bool isUnlock,
  }) {
    return showModalBottomSheet<({String cid, String folderName})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Dian115TransferConfirmSheet(
        item: item,
        mediaType: mediaType,
        mediaTitle: mediaTitle,
        userPoints: userPoints,
        isUnlock: isUnlock,
      ),
    );
  }

  @override
  State<Dian115TransferConfirmSheet> createState() =>
      _Dian115TransferConfirmSheetState();
}

class _Dian115TransferConfirmSheetState
    extends State<Dian115TransferConfirmSheet> {
  late String _selectedCid;
  late String _selectedFolderName;

  @override
  void initState() {
    super.initState();
    final pan115 = Pan115Service.to;
    final isMovie = Pan115Service.isMovieType(
      mediaType: widget.mediaType,
      item: widget.item,
    );

    if (isMovie) {
      _selectedCid = pan115.movieCid.value.isNotEmpty
          ? pan115.movieCid.value
          : Pan115Service.defaultMovieCid;
      _selectedFolderName = '电影目录';
    } else {
      _selectedCid = pan115.tvCid.value.isNotEmpty
          ? pan115.tvCid.value
          : Pan115Service.defaultTvCid;
      _selectedFolderName = '电视剧目录';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pan115 = Pan115Service.to;
    final movieCid = pan115.movieCid.value.isNotEmpty
        ? pan115.movieCid.value
        : Pan115Service.defaultMovieCid;
    final tvCid = pan115.tvCid.value.isNotEmpty
        ? pan115.tvCid.value
        : Pan115Service.defaultTvCid;

    final isMovieSelected = _selectedCid == movieCid;
    final item = widget.item;
    final title = item.fileName.isNotEmpty
        ? item.fileName
        : (widget.mediaTitle.isNotEmpty ? widget.mediaTitle : '网盘片源');

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161C26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部小横条
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

          // 弹窗主标题
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.cloud_download_fill,
                  color: Color(0xFF34D399),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isUnlock ? '确认解锁并转存' : '确认转存至 115 网盘',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 目录选择提示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '保存目标目录',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '已按片源自动预选，可点击切换',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 两个目录选择卡片
          Row(
            children: [
              // 电影目录卡片
              Expanded(
                child: _buildFolderCard(
                  title: '电影目录',
                  icon: CupertinoIcons.film,
                  cid: movieCid,
                  isSelected: isMovieSelected,
                  onTap: () {
                    setState(() {
                      _selectedCid = movieCid;
                      _selectedFolderName = '电影目录';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // 电视剧目录卡片
              Expanded(
                child: _buildFolderCard(
                  title: '电视剧目录',
                  icon: CupertinoIcons.tv,
                  cid: tvCid,
                  isSelected: !isMovieSelected,
                  onTap: () {
                    setState(() {
                      _selectedCid = tvCid;
                      _selectedFolderName = '电视剧目录';
                    });
                  },
                ),
              ),
            ],
          ),

          // 多链接全量转存提示
          if (item.urls.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.square_stack_3d_up_fill,
                    size: 14,
                    color: Color(0xFF818CF8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '该资源共包含 ${item.urls.length} 个分集/离线链接，将全部批量添加至目标目录',
                      style: const TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 若需要解锁扣分，展示积分明细
          if (widget.isUnlock && item.unlockCost > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.money_dollar_circle_fill,
                    size: 16,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本次解锁将消耗 ${item.unlockCost} 积分（当前余额: ${widget.userPoints} 分，转存后剩余: ${(widget.userPoints - item.unlockCost).clamp(0, 999999)} 分）',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 底部操作按钮
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    Navigator.of(context).pop((
                      cid: _selectedCid,
                      folderName: _selectedFolderName,
                    ));
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 16,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isUnlock ? '确认解锁并转存' : '立即转存',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required IconData icon,
    required String cid,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF34D399) : Colors.white60,
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark,
                      size: 11,
                      color: Colors.black,
                    ),
                  )
                else
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'CID: $cid',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF6EE7B7)
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
