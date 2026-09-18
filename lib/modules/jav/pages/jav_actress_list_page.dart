import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/controllers/jav_controller.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

enum ActressSortType {
  popularity('综合热度', Icons.local_fire_department_rounded),
  worksCount('作品数量', Icons.movie_filter_rounded),
  alphabetical('名字拼音', Icons.sort_by_alpha_rounded);

  final String label;
  final IconData icon;
  const ActressSortType(this.label, this.icon);
}

class JavActressListPage extends StatefulWidget {
  const JavActressListPage({super.key});

  @override
  State<JavActressListPage> createState() => _JavActressListPageState();
}

class _JavActressListPageState extends State<JavActressListPage> {
  static const Color _themeColor = Color(0xFF061815);
  final JavApiService _api = JavApiService();

  final List<JavActress> _rawList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();
  ActressSortType _currentSort = ActressSortType.popularity;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchActresses(isRefresh: true);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchActresses(isRefresh: false);
      }
    }
  }

  Future<void> _fetchActresses({bool isRefresh = true}) async {
    if (isRefresh) {
      _page = 1;
      _hasMore = true;
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final list = await _api.fetchActresses(
        page: _page,
        limit: 30,
        cancelToken: _cancelToken,
      );
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _rawList.clear();
          }
          if (list.isEmpty) {
            _hasMore = false;
          } else {
            final existingIds = _rawList.map((e) => e.starId).toSet();
            final newItems = list.where((e) => e.starId.isNotEmpty && !existingIds.contains(e.starId)).toList();
            _rawList.addAll(newItems.isNotEmpty ? newItems : list);
            if (list.length < 30) {
              _hasMore = false;
            } else {
              _page++;
            }
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<JavActress> get _sortedList {
    final list = List<JavActress>.from(_rawList);
    switch (_currentSort) {
      case ActressSortType.popularity:
        return list;
      case ActressSortType.worksCount:
        list.sort((a, b) => b.count.compareTo(a.count));
        return list;
      case ActressSortType.alphabetical:
        list.sort((a, b) {
          final pA = a.pinyin.isNotEmpty ? a.pinyin : a.name;
          final pB = b.pinyin.isNotEmpty ? b.pinyin : b.name;
          return pA.compareTo(pB);
        });
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedList;

    return Scaffold(
      backgroundColor: _themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
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
        title: const Text(
          '全部女优',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Obx(() {
            final isSafe = JavSafeService.to.isSafeMode.value;
            return Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSafe
                    ? Colors.cyanAccent.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSafe
                      ? Colors.cyanAccent.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: JavSafeService.to.toggleSafeMode,
                child: Icon(
                  isSafe ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                  color: isSafe ? Colors.cyanAccent : Colors.white70,
                  size: 16,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (Get.isRegistered<JavController>()) {
                    Get.find<JavController>().exitJav();
                  } else {
                    Get.offAllNamed('/main', arguments: {'initialIndex': 0});
                  }
                },
                child: const Icon(CupertinoIcons.shield_fill, color: Colors.redAccent, size: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSortPillsBar(),
          Expanded(
            child: _isLoading && _rawList.isEmpty
                ? const Center(
                    child: CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 14),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () => _fetchActresses(isRefresh: true),
                      ),
                      if (sorted.isEmpty && !_isLoading)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              '暂无女优名录数据',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildActressCard(context, sorted[index]),
                              childCount: sorted.length,
                            ),
                          ),
                        ),
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 12),
                            ),
                          ),
                        )
                      else if (!_hasMore && _rawList.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                '已加载全部女优',
                                style: TextStyle(color: Colors.white30, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 50),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortPillsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withValues(alpha: 0.2),
      child: Row(
        children: [
          for (final sortType in ActressSortType.values) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_currentSort != sortType) {
                  setState(() => _currentSort = sortType);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _currentSort == sortType
                      ? Colors.cyanAccent.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentSort == sortType
                        ? Colors.cyanAccent.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sortType.icon,
                      size: 14,
                      color: _currentSort == sortType ? Colors.cyanAccent : Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sortType.label,
                      style: TextStyle(
                        color: _currentSort == sortType ? Colors.cyanAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: _currentSort == sortType ? FontWeight.bold : FontWeight.normal,
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
  }

  Widget _buildActressCard(BuildContext context, JavActress actress) {
    final proxyAvatar = _api.getProxyImageUrl(actress.avatar);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed(
        '/jav/category',
        arguments: {'title': '${actress.name} 的作品', 'actress': actress.name},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF102320),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.pinkAccent, Colors.purpleAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Obx(() {
                      final isSafe = JavSafeService.to.isSafeMode.value;
                      if (isSafe || proxyAvatar.isEmpty) {
                        return _buildAvatarPlaceholder(actress.name);
                      }
                      return CachedImage(
                        imageUrl: proxyAvatar,
                        fit: BoxFit.cover,
                        errorWidget: _buildAvatarPlaceholder(actress.name),
                      );
                    }),
                  ),
                ),
                if (actress.badge != null && actress.badge!.isNotEmpty)
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        actress.badge!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              actress.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (actress.kanji.isNotEmpty && actress.kanji != actress.name) ...[
              const SizedBox(height: 2),
              Text(
                actress.kanji,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${actress.count > 0 ? actress.count : '--'} 部作品',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initial = name.isNotEmpty ? name.characters.first : '女';
    return Container(
      color: const Color(0xFF1E3531),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
