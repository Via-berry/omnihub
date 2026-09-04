import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/jav/models/jav_models.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';
import 'package:moviepilot_mobile/widgets/cached_image.dart';
import 'package:soft_edge_blur/soft_edge_blur.dart';

class JavBannerCard extends StatelessWidget {
  const JavBannerCard({
    super.key,
    required this.item,
    required this.onTap,
    this.themeColor = const Color(0xFF061815),
  });

  final JavItem item;
  final VoidCallback onTap;
  final Color themeColor;

  static const double bannerHeight = 450;
  static const double stripHeight = 220;

  @override
  Widget build(BuildContext context) {
    final proxyUrl = JavApiService().getProxyImageUrl(item.cover, code: item.code);

    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackdrop(proxyUrl),
          _buildMask(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            height: stripHeight,
            child: _buildInfo(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop(String url) {
    return SoftEdgeBlur(
      edges: [
        EdgeBlur(
          type: EdgeType.bottomEdge,
          size: 200,
          sigma: 30,
          controlPoints: [
            ControlPoint(position: 0.5, type: ControlPointType.visible),
            ControlPoint(position: 0.8, type: ControlPointType.visible),
            ControlPoint(position: 1, type: ControlPointType.transparent),
          ],
        ),
      ],
      child: url.isNotEmpty
          ? CachedImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: Container(
                color: const Color(0xFF10211F),
                child: const Center(
                  child: Icon(Icons.movie_outlined, color: Colors.white24, size: 64),
                ),
              ),
            )
          : Container(color: themeColor),
    );
  }

  Widget _buildMask() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            themeColor.withValues(alpha: 0.2),
            themeColor.withValues(alpha: 0.65),
            themeColor,
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final displayDate = item.date.isNotEmpty ? item.date : '2023';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayDate,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DMM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 40,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: CupertinoColors.inactiveGray
                    .resolveFrom(context)
                    .withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '查看',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
