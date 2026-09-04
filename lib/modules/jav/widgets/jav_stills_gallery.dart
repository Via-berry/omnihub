import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

class JavStillsGallery extends StatelessWidget {
  const JavStillsGallery({
    super.key,
    required this.samplePhotos,
    required this.code,
  });

  final List<String> samplePhotos;
  final String code;

  @override
  Widget build(BuildContext context) {
    if (samplePhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: samplePhotos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final rawUrl = samplePhotos[index];
          final proxyUrl = JavApiService().getProxyImageUrl(rawUrl, code: code);

          return GestureDetector(
            onTap: () => _openFullscreenGallery(context, index),
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF10211F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedImage(
                      imageUrl: proxyUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: const Color(0xFF152220),
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: Colors.white30, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '剧照 #${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullscreenGallery(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) {
        final pageController = PageController(initialPage: initialIndex);
        final currentIndex = initialIndex.obs;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: pageController,
                itemCount: samplePhotos.length,
                onPageChanged: (i) => currentIndex.value = i,
                itemBuilder: (context, i) {
                  final rawUrl = samplePhotos[i];
                  final proxyUrl = JavApiService().getProxyImageUrl(rawUrl, code: code);

                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.5,
                    child: Center(
                      child: CachedImage(
                        imageUrl: proxyUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            '样张 ${currentIndex.value + 1} / ${samplePhotos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
