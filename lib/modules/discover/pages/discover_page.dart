import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/discover/controllers/discover_controller.dart';
import 'package:moviepilot_mobile/modules/discover/widgets/discover_filter_sheet.dart';
import 'package:moviepilot_mobile/modules/recommend/models/recommend_api_item.dart';
import 'package:moviepilot_mobile/services/app_service.dart';
import 'package:moviepilot_mobile/utils/grid_layout.dart';
import 'package:moviepilot_mobile/utils/http_path_builder_util.dart';
import 'package:moviepilot_mobile/utils/image_util.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';
import 'package:moviepilot_mobile/widgets/constrained_page_content.dart';

class DiscoverPage extends GetView<DiscoverController> {
  const DiscoverPage({super.key, this.scrollController});

  final ScrollController? scrollController;

  static const double _gridSpacing = 6;
  static const double _gridPadding = 0;
  static const double _cardAspectRatio = 0.72;
  static const double _wideBreakpoint = ConstrainedPageContent.wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureUserCookieRefreshed();
    });
    final appService = Get.find<AppService>();
    return Obx(() {
      final hasPageBackground =
          appService.backgroundImageEnabled.value &&
          appService.backgroundImageBytes.value != null;
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: _buildNavigationBar(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPageBackground)
              Positioned.fill(child: _buildBackgroundImage(context, appService))
            else
              const Positioned.fill(child: _DiscoverAtmosphere()),
            CustomScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async =>
                      controller.loadCurrent(forceRefresh: true),
                ),
                SliverToBoxAdapter(
                  child: Obx(() => _buildPageContent(context)),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: _bottomSpacer(context)),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  double _bottomSpacer(BuildContext context) {
    return 104;
  }

  bool _isWideScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width > _wideBreakpoint;
  }

  GridLayout _discoverGridLayout(double width) {
    final int crossAxisCount;
    if (width >= 900) {
      crossAxisCount = 5;
    } else if (width >= 720) {
      crossAxisCount = 4;
    } else if (width >= 520) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }
    final available =
        width - (_gridPadding * 2) - (_gridSpacing * (crossAxisCount - 1));
    return GridLayout(
      crossAxisCount: crossAxisCount,
      cardWidth: available / crossAxisCount,
    );
  }

  Widget _buildPageContent(BuildContext context) {
    final isWide = _isWideScreen(context);
    final top = MediaQuery.paddingOf(context).top;

    return ConstrainedPageContent(
      padding: EdgeInsets.only(top: top + 68),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHero(context, isWide: isWide),
          _buildSourceBar(context),
          _buildSection(context),
        ],
      ),
    );
  }

  AppBar _buildNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      foregroundColor: colorScheme.onSurface,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {},
        child: Icon(Icons.explore_outlined, color: colorScheme.onSurface),
      ),
      title: Text(
        'Discover',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _GlassButton(
            icon: Icons.tune_rounded,
            label: '筛选',
            compact: true,
            onTap: () => _openFilterSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(BuildContext context, AppService appService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = appService.backgroundImageBytes.value;
    if (bytes == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: appService.backgroundImageOpacity.value,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  appService.backgroundImageGradientTop.value,
                  appService.backgroundImageGradientBottom.value,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.62 : 0.34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, {bool isWide = false}) {
    final items = controller.currentItems();
    final isLoading = controller.isLoading();
    final hero = items.isNotEmpty ? items.first : null;
    final imageUrl = _imageUrl(hero, preferBackdrop: true);
    final title = hero == null ? '探索发现' : _bestTitle(hero) ?? 'Untitled';
    final source = controller.selectedSource.value;
    final subtitle = isLoading && hero == null
        ? '正在校准片库雷达'
        : hero?.overview?.trim().isNotEmpty == true
        ? hero!.overview!.trim()
        : '从 ${source.label} 中发现下一部值得停留的作品';
    final meta = _compactHeroMeta(hero, source);
    final heroHeight = isWide ? 326.0 : 286.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: hero == null ? null : () => _openDetail(hero),
        child: Container(
          height: heroHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.16 : 0.09,
                ),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: isDark ? 0.32 : 0.12,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildHeroBody(
            context,
            hero: hero,
            imageUrl: imageUrl,
            title: title,
            subtitle: subtitle,
            meta: meta,
            isWide: isWide,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBody(
    BuildContext context, {
    required RecommendApiItem? hero,
    required String imageUrl,
    required String title,
    required String subtitle,
    required String meta,
    required bool isWide,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          CachedImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: const _HeroPlaceholder(),
            errorWidget: const _HeroPlaceholder(),
          )
        else
          const _HeroPlaceholder(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x14000000), Color(0x5A000000), Color(0xEE050506)],
              stops: [0.08, 0.48, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.95, -0.85),
              radius: 1.05,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned(
          left: isWide ? 28 : 18,
          right: isWide ? 28 : 18,
          bottom: isWide ? 24 : 20,
          child: _buildHeroCopy(
            context,
            hero: hero,
            title: title,
            subtitle: subtitle,
            meta: meta,
            isWide: isWide,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCopy(
    BuildContext context, {
    required RecommendApiItem? hero,
    required String title,
    required String subtitle,
    required String meta,
    required bool isWide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: isWide ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.02,
            letterSpacing: -0.6,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          subtitle,
          maxLines: isWide ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _PrimaryActionButton(
            enabled: hero != null,
            onTap: hero == null ? null : () => _openDetail(hero),
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBar(BuildContext context) {
    final sources = controller.sourceEntries.toList();
    if (sources.isEmpty) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < sources.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _buildSourceChip(context, sources[i]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: '调整筛选条件',
            child: _GlassButton(
              icon: Icons.tune_rounded,
              label: '筛选',
              compact: true,
              onTap: () => _openFilterSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(BuildContext context, DiscoverSourceEntry source) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = controller.selectedSource.value == source;
    return Semantics(
      button: true,
      selected: selected,
      label: '探索来源 ${source.label}',
      child: InkWell(
        onTap: () => controller.selectSource(source),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.14)
                : colorScheme.surface.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_rounded
                    : source.isDynamic
                    ? Icons.auto_awesome_rounded
                    : Icons.movie_filter_outlined,
                size: 15,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                source.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    final items = controller.currentItems();
    final isLoading = controller.isLoading();
    final errorText = controller.errorText();
    final gridItems = items.length > 1 ? items.skip(1).toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty && isLoading)
          _buildLoadingGrid(context)
        else if (items.isEmpty && errorText != null)
          _buildEmptyRail(context, errorText)
        else if (items.isEmpty)
          _buildEmptyRail(context, '当前条件暂时没有匹配作品')
        else
          _buildItemsList(context, gridItems),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, List<RecommendApiItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        switch (index % 3) {
          case 0:
            return _buildWideListCard(context, item);
          case 1:
            return _buildInfoListCard(context, item, imageOnLeft: true);
          default:
            return _buildInfoListCard(context, item, imageOnLeft: false);
        }
      },
    );
  }

  Widget _buildWideListCard(BuildContext context, RecommendApiItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _bestTitle(item) ?? 'Untitled';
    final imageUrl = _imageUrl(item, preferBackdrop: true);
    return Semantics(
      button: true,
      label: '打开 $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 214,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: const _HeroPlaceholder(),
                    errorWidget: const _HeroPlaceholder(),
                  )
                else
                  const _HeroPlaceholder(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x11000000),
                        Color(0xB8000000),
                        Color(0xF0050506),
                      ],
                      stops: [0.22, 0.62, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _itemMeta(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.vote_average != null && item.vote_average! > 0)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _ListRatingPill(value: item.vote_average!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoListCard(
    BuildContext context,
    RecommendApiItem item, {
    required bool imageOnLeft,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _bestTitle(item) ?? 'Untitled';
    final image = _imageUrl(item);
    final poster = SizedBox(
      width: 92,
      height: 132,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: image.isEmpty
            ? const _DiscoverListPosterPlaceholder()
            : CachedImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: const _DiscoverListPosterPlaceholder(),
                errorWidget: const _DiscoverListPosterPlaceholder(),
              ),
      ),
    );
    final copy = Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          left: imageOnLeft ? 14 : 0,
          right: imageOnLeft ? 0 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _itemMeta(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.overview?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                item.overview!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: '打开 $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: imageOnLeft
                  ? [poster, copy]
                  : [copy, const SizedBox(width: 4), poster],
            ),
          ),
        ),
      ),
    );
  }

  String _itemMeta(RecommendApiItem item) {
    final year = item.year?.trim() ?? item.title_year?.trim() ?? '';
    final type = item.type?.trim() ?? '';
    final vote = item.vote_average;
    return [
      if (year.isNotEmpty) year,
      if (type.isNotEmpty) type,
      if (vote != null && vote > 0) '★ ${vote.toStringAsFixed(1)}',
    ].join(' · ');
  }

  Widget _buildLoadingGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _discoverGridLayout(constraints.maxWidth);
        final placeholderCount = layout.crossAxisCount * 3;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: placeholderCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.crossAxisCount,
            crossAxisSpacing: _gridSpacing,
            mainAxisSpacing: _gridSpacing,
            childAspectRatio: _cardAspectRatio,
          ),
          itemBuilder: (context, index) => const _DiscoverCardSkeleton(),
        );
      },
    );
  }

  Widget _buildEmptyRail(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gridPadding, 8, _gridPadding, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: isDark ? 0.66 : 0.94),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.34),
                    colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '片场暂时安静',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _GlassButton(
              icon: Icons.tune_rounded,
              label: '调整筛选条件',
              onTap: () => _openFilterSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<DiscoverFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DiscoverFilterSheet(
        initialSource: controller.selectedSource.value,
        sources: controller.sourceEntries.toList(),
        filtersBySource: controller.snapshotFiltersBySource(),
        dynamicFiltersBySource: controller.snapshotDynamicFiltersBySource(),
      ),
    );
    if (result == null) return;
    controller.applySelection(
      result.selectedSource,
      result.filtersBySource,
      result.dynamicFiltersBySource,
    );
  }

  String _compactHeroMeta(RecommendApiItem? item, DiscoverSourceEntry source) {
    final result = <String>[source.label];
    if (item == null) return result.join(' · ');
    final type = item.type?.trim() ?? '';
    final year = item.year?.trim() ?? item.title_year?.trim() ?? '';
    final vote = item.vote_average;
    if (type.isNotEmpty) result.add(type);
    if (year.isNotEmpty) result.add(year);
    if (vote != null && vote > 0) result.add('★ ${vote.toStringAsFixed(1)}');
    return result.join(' · ');
  }

  String _imageUrl(RecommendApiItem? item, {bool preferBackdrop = false}) {
    if (item == null) return '';
    final raw = preferBackdrop
        ? item.backdrop_path ?? item.poster_path ?? ''
        : item.poster_path ?? item.backdrop_path ?? '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return ImageUtil.convertCacheImageUrl(trimmed);
  }

  void _openDetail(RecommendApiItem item) {
    final path = HttpPathBuilderUtil.buildMediaPath(item);
    if (path.isEmpty) {
      ToastUtil.info('暂无可用详情信息');
      return;
    }
    final title = _bestTitle(item);
    final params = <String, String>{
      'path': path,
      if (title != null && title.isNotEmpty) 'title': title,
      if (item.year != null && item.year!.isNotEmpty) 'year': item.year!,
      if (item.type != null && item.type!.isNotEmpty) 'type_name': item.type!,
      if (item.poster_path != null && item.poster_path!.isNotEmpty)
        'poster_path': item.poster_path!,
      if (item.backdrop_path != null && item.backdrop_path!.isNotEmpty)
        'backdrop_path': item.backdrop_path!,
      if (item.vote_average != null && item.vote_average! > 0)
        'vote_average': item.vote_average!.toStringAsFixed(1),
    };
    Get.toNamed('/media-detail', parameters: params);
  }

  String? _bestTitle(RecommendApiItem item) {
    final title = item.title;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    final enTitle = item.en_title;
    if (enTitle != null && enTitle.trim().isNotEmpty) return enTitle.trim();
    final original = item.original_title ?? item.original_name;
    if (original != null && original.trim().isNotEmpty) {
      return original.trim();
    }
    return null;
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: compact ? 34 : 44,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.56 : 0.72,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: colorScheme.onSurface,
                  size: compact ? 16 : 19,
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = Color.lerp(
      colorScheme.primary,
      colorScheme.secondary,
      0.36,
    )!;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.62,
        child: Container(
          height: compact ? 40 : 46,
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, accent],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: compact ? 22 : 24,
              ),
              const SizedBox(width: 5),
              Text(
                '查看详情',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverAtmosphere extends StatelessWidget {
  const _DiscoverAtmosphere();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.72, -0.92),
          radius: 1.25,
          colors: [
            colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
            Colors.transparent,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withValues(alpha: isDark ? 0.035 : 0.32),
              Colors.transparent,
              colorScheme.surface.withValues(alpha: isDark ? 0.18 : 0.28),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.primary.withValues(alpha: isDark ? 0.34 : 0.22),
            colorScheme.surface.withValues(alpha: isDark ? 0.90 : 0.72),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_movies_rounded,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.18),
          size: 88,
        ),
      ),
    );
  }
}

class _DiscoverCardSkeleton extends StatelessWidget {
  const _DiscoverCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.66 : 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.58,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
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
}

class _ListRatingPill extends StatelessWidget {
  const _ListRatingPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '★ ${value.toStringAsFixed(1)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DiscoverListPosterPlaceholder extends StatelessWidget {
  const _DiscoverListPosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_creation_outlined,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
        size: 32,
      ),
    );
  }
}
