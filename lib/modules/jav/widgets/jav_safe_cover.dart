import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_safe_service.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';

/// 统一的脱敏封面组件
/// 在避人模式开启时，对敏感海报施加强力高斯模糊与暗色遮罩
/// 支持长按单卡临时透视原图
class JavSafeCover extends StatelessWidget {
  const JavSafeCover({
    super.key,
    required this.imageUrl,
    this.code = '',
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.blurSigma = 26.0,
    this.errorWidget,
    this.showBadge = true,
    this.enablePeeking = true,
  });

  final String imageUrl;
  final String code;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Widget? errorWidget;
  final bool showBadge;
  final bool enablePeeking;

  @override
  Widget build(BuildContext context) {
    final safeService = JavSafeService.to;

    return Obx(() {
      final isBlurred = safeService.isItemBlurred(code);

      Widget imageContent = SizedBox(
        width: width,
        height: height,
        child: imageUrl.isNotEmpty
            ? CachedImage(
                imageUrl: imageUrl,
                fit: fit,
                width: width,
                height: height,
                borderRadius: borderRadius,
                errorWidget: errorWidget ??
                    Container(
                      color: const Color(0xFF10211F),
                      child: const Center(
                        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 32),
                      ),
                    ),
              )
            : (errorWidget ?? Container(color: const Color(0xFF10211F))),
      );

      if (isBlurred) {
        imageContent = ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 强力高斯模糊滤镜
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: imageContent,
              ),
              // 暗夜半透明磨砂遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              // 中心避人模式微缩护盾水印
              if (showBadge)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(
                      CupertinoIcons.eye_slash_fill,
                      color: Colors.cyanAccent,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      if (!enablePeeking || code.isEmpty) {
        return imageContent;
      }

      // 允许长按单卡透视
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (_) => safeService.startPeeking(code),
        onLongPressEnd: (_) => safeService.stopPeeking(code),
        onLongPressCancel: () => safeService.stopPeeking(code),
        child: imageContent,
      );
    });
  }
}
