import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/modules/jav/widgets/jav_safe_cover.dart';

class JavNowPlayingCard extends StatelessWidget {
  const JavNowPlayingCard({
    super.key,
    required this.item,
    required this.onTap,
    this.score = 9.6,
  });

  final JavItem item;
  final VoidCallback onTap;
  final double score;

  static const double cardWidth = 116;
  static const double cardHeight = 180;

  @override
  Widget build(BuildContext context) {
    final title = item.code.isNotEmpty ? item.code : item.title;
    final proxyUrl = JavApiService().getProxyImageUrl(item.cover, code: item.code);

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF10211F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFF0B1716),
                    child: proxyUrl.isNotEmpty
                        ? JavSafeCover(
                            imageUrl: proxyUrl,
                            code: item.code,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: const Color(0xFF10211F),
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white24,
                                size: 32,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 0.8, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0xB3000000),
                          Color(0xF2000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Color(0xFFFFC857),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            score.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
