import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';

enum SearchSourceType {
  pt,
  dian115,
}

class SearchSourceSelectSheet extends StatelessWidget {
  const SearchSourceSelectSheet({super.key});

  static Future<SearchSourceType?> show(BuildContext context) {
    return showModalBottomSheet<SearchSourceType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SearchSourceSelectSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dian115 = Dian115Service.to;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽条
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
          const SizedBox(height: 14),

          // 弹窗头部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择资源搜索渠道',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '请选择需要检索的片源网络类型',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
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
          const SizedBox(height: 16),

          // 渠道 1：PT 站聚合搜索
          InkWell(
            onTap: () => Navigator.of(context).pop(SearchSourceType.pt),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D82FE).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1D82FE).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_down_to_line_alt,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'PT 站聚合搜索',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '经典',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '检索已绑定的私有 PT 站点，支持分季与选种',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 渠道 2：115 网盘 / 癫影资源
          InkWell(
            onTap: () => Navigator.of(context).pop(SearchSourceType.dian115),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF064E3B).withValues(alpha: 0.35),
                    const Color(0xFF112620),
                    const Color(0xFF161B22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.cloud_download_fill,
                      color: Color(0xFF34D399),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '115 网盘资源（癫影）',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                '秒转存·免做种',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '片源直连 · 4K 蓝光高码率原盘',
                          style: TextStyle(
                            color: const Color(0xFF34D399).withValues(alpha: 0.70),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(() {
                    final points = dian115.accountStatus.value?.points;
                    return Row(
                      children: [
                        if (points != null && points > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$points 分',
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: Color(0xFF34D399),
                        ),
                      ],
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
}
