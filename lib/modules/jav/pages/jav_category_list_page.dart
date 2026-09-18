import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_now_playing_card.dart';

class JavCategoryListPage extends StatefulWidget {
  const JavCategoryListPage({super.key});

  @override
  State<JavCategoryListPage> createState() => _JavCategoryListPageState();
}

class _JavCategoryListPageState extends State<JavCategoryListPage> {
  static const Color _themeColor = Color(0xFF061815);
  final JavApiService _api = JavApiService();

  late final String _title;
  late final String _categoryType;
  late final String _genre;

  final List<JavItem> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _activeFilter = 'all'; // all, sub, hd

  final ScrollController _scrollController = ScrollController();
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _title = args['title']?.toString() ?? '专区作品';
    _categoryType = args['categoryType']?.toString() ?? 'censored';
    _genre = args['genre']?.toString() ?? '';

    _scrollController.addListener(_onScroll);
    _fetchPage(isRefresh: true);
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
        _fetchPage(isRefresh: false);
      }
    }
  }

  Future<void> _fetchPage({required bool isRefresh}) async {
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
      final items = await _api.fetchCategoryExplore(
        category: _categoryType,
        genre: _genre,
        page: _page,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _movies.clear();
          }
          if (items.isEmpty) {
            _hasMore = false;
          } else {
            final existing = _movies.map((e) => e.code).toSet();
            final newItems = items.where((e) => !existing.contains(e.code)).toList();
            _movies.addAll(newItems);
            _page++;
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

  List<JavItem> get _filteredMovies {
    if (_activeFilter == 'sub') {
      return _movies.where((m) => m.hasSubtitles).toList();
    } else if (_activeFilter == 'hd') {
      return _movies.where((m) => m.isHd).toList();
    }
    return _movies;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Get.back(),
          child: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 22),
        ),
        title: Text(
          _title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          Obx(() {
            final isSafe = JavSafeService.to.isSafeMode.value;
            return CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: JavSafeService.to.toggleSafeMode,
              child: Icon(
                isSafe ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                color: isSafe ? Colors.cyanAccent : Colors.white70,
                size: 20,
              ),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading && _movies.isEmpty
                ? const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 14))
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () => _fetchPage(isRefresh: true),
                      ),
                      if (_filteredMovies.isEmpty && !_isLoading)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              '暂无匹配作品',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _filteredMovies[index];
                                return JavNowPlayingCard(
                                  item: item,
                                  width: double.infinity,
                                  onTap: () {
                                    Get.toNamed('/jav/detail', parameters: {'code': item.code});
                                  },
                                );
                              },
                              childCount: _filteredMovies.length,
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
                      else if (!_hasMore && _movies.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                '已加载全部母库作品',
                                style: TextStyle(color: Colors.white24, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        children: [
          _buildChipItem('全部', 'all'),
          const SizedBox(width: 8),
          _buildChipItem('中文字幕', 'sub'),
          const SizedBox(width: 8),
          _buildChipItem('高清4K/1080P', 'hd'),
          const Spacer(),
          Text(
            '已收录 ${_filteredMovies.length} 部',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildChipItem(String label, String key) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.6) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
