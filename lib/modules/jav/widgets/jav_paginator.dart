import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用移动端/桌面端暗色风格分页器组件
class JavPaginator extends StatefulWidget {
  const JavPaginator({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
    this.totalPages,
    this.hasMore = true,
    this.isLoading = false,
  });

  /// 当前页码 (从 1 开始)
  final int currentPage;

  /// 总页数 (若未知则根据 hasMore 动态推断)
  final int? totalPages;

  /// 是否还有下一页
  final bool hasMore;

  /// 是否正在加载目标页数据
  final bool isLoading;

  /// 页码切换回调
  final ValueChanged<int> onPageChanged;

  @override
  State<JavPaginator> createState() => _JavPaginatorState();
}

class _JavPaginatorState extends State<JavPaginator> {
  late final TextEditingController _jumpController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _jumpController = TextEditingController(text: '${widget.currentPage}');
  }

  @override
  void didUpdateWidget(covariant JavPaginator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage && !_focusNode.hasFocus) {
      _jumpController.text = '${widget.currentPage}';
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _effectiveTotalPages {
    if (widget.totalPages != null && widget.totalPages! > 0) {
      return widget.totalPages!;
    }
    if (!widget.hasMore) {
      return widget.currentPage > 0 ? widget.currentPage : 1;
    }
    return widget.currentPage < 20 ? 50 : widget.currentPage + 10;
  }

  void _handlePageChange(int targetPage) {
    if (widget.isLoading) return;
    final clamped = targetPage.clamp(1, _effectiveTotalPages);
    if (clamped == widget.currentPage) return;
    _jumpController.text = '$clamped';
    widget.onPageChanged(clamped);
  }

  void _handleJumpSubmit() {
    final text = _jumpController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed != null) {
      _focusNode.unfocus();
      _handlePageChange(parsed);
    } else {
      _jumpController.text = '${widget.currentPage}';
    }
  }

  List<int> _buildPagePills(int total) {
    final current = widget.currentPage;
    if (total <= 7) {
      return List.generate(total, (i) => i + 1);
    }

    final pills = <int>[];
    if (current <= 4) {
      for (int i = 1; i <= 5; i++) {
        pills.add(i);
      }
      pills.add(-1); // 省略号
      pills.add(total);
    } else if (current >= total - 3) {
      pills.add(1);
      pills.add(-1); // 省略号
      for (int i = total - 4; i <= total; i++) {
        pills.add(i);
      }
    } else {
      pills.add(1);
      pills.add(-1); // 前置省略号
      pills.add(current - 1);
      pills.add(current);
      pills.add(current + 1);
      pills.add(-2); // 后置省略号
      pills.add(total);
    }
    return pills;
  }

  @override
  Widget build(BuildContext context) {
    final total = _effectiveTotalPages;
    final canPrev = widget.currentPage > 1 && !widget.isLoading;
    final canNext = (widget.hasMore || widget.currentPage < total) && !widget.isLoading;
    final pills = _buildPagePills(total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B211E).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：上一页、页码胶囊列表、下一页
          Row(
            children: [
              // 上一页
              _buildNavButton(
                icon: CupertinoIcons.chevron_left_2,
                label: 'Prev',
                enabled: canPrev,
                onTap: () => _handlePageChange(widget.currentPage - 1),
              ),
              const SizedBox(width: 6),
              // 页码胶囊横向滑动列表
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pills.map((p) {
                      if (p < 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      final isSelected = p == widget.currentPage;
                      return GestureDetector(
                        onTap: () => _handlePageChange(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.cyanAccent
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.cyanAccent
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF041916) : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 下一页
              _buildNavButton(
                icon: CupertinoIcons.chevron_right_2,
                label: 'Next',
                enabled: canNext,
                onTap: () => _handlePageChange(widget.currentPage + 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 8),
          // 第二行：当前页码统计 & 输入跳转
          Row(
            children: [
              // 状态统计提示
              Expanded(
                child: Row(
                  children: [
                    if (widget.isLoading) ...[
                      const CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 7),
                      const SizedBox(width: 6),
                      const Text(
                        '正在载入...',
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 11),
                      ),
                    ] else ...[
                      Text(
                        '第 ${widget.currentPage} 页',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (widget.totalPages != null) ...[
                        Text(
                          ' / 共 $total 页',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ] else if (widget.hasMore) ...[
                        Text(
                          ' (支持持续翻页)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ] else ...[
                        Text(
                          ' (已到尾页)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              // 输入跳转区域
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '跳至',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 46,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: TextField(
                      controller: _jumpController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleJumpSubmit(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.isLoading ? null : _handleJumpSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyanAccent.withValues(alpha: 0.8),
                            Colors.blueAccent.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '跳转',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.cyanAccent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? Colors.cyanAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'Prev') ...[
                Icon(icon, size: 12, color: enabled ? Colors.cyanAccent : Colors.white54),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.cyanAccent : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (label == 'Next') ...[
                const SizedBox(width: 3),
                Icon(icon, size: 12, color: enabled ? Colors.cyanAccent : Colors.white54),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
