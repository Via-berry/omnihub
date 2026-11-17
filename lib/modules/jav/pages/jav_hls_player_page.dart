import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:moviepilot_mobile/modules/jav/services/jav_api_service.dart';

class JavHlsPlayerPage extends StatefulWidget {
  const JavHlsPlayerPage({super.key});

  @override
  State<JavHlsPlayerPage> createState() => _JavHlsPlayerPageState();
}

class _JavHlsPlayerPageState extends State<JavHlsPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription? _errorSubscription;
  StreamSubscription? _bufferingSubscription;

  String _url = '';
  String _code = '';
  String _title = '原生高清播放';
  String _fallbackUrl = '';

  bool _hasError = false;
  String _errorMessage = '';
  bool _isBuffering = true;
  double _playbackRate = 1.0;
  bool _isRefreshingStream = false;

  final JavApiService _api = JavApiService();

  static const List<double> _availableRates = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    final params = Get.parameters;
    _url = (params['url'] ?? '').trim();
    _code = (params['code'] ?? '').trim();
    _title = params['title'] ?? _code;
    _fallbackUrl = (params['fallbackUrl'] ?? '').trim();

    _player = Player();
    _videoController = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _errorSubscription = _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    });

    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      if (mounted && _isBuffering != buffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    await _openStream(_url);
  }

  Future<void> _openStream(String streamUrl) async {
    if (streamUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = '未获取到可用的 HLS 流媒体播放地址';
      });
      return;
    }

    var playUrl = streamUrl;
    if (playUrl.contains('surrit.com') && !playUrl.contains('/api/jav/hls/proxy')) {
      final encoded = Uri.encodeComponent(playUrl);
      playUrl = '${_api.baseUrl}/api/jav/hls/proxy?url=$encoded';
    }

    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isBuffering = true;
    });

    try {
      await _player.open(
        Media(
          playUrl,
          httpHeaders: {
            'Referer': 'https://missav.ai/',
            'Origin': 'https://missav.ai',
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          },
        ),
      );
      if (_playbackRate != 1.0) {
        await _player.setRate(_playbackRate);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '初始化流媒体播放失败: $e';
        });
      }
    }
  }

  /// 重新向后端请求最新解密的 m3u8 直链并重试
  Future<void> _retryWithFreshStream() async {
    if (_code.isEmpty) {
      _openStream(_url);
      return;
    }

    setState(() {
      _isRefreshingStream = true;
      _hasError = false;
    });

    try {
      final freshStreams = await _api.fetchStreams(_code);
      final newUrl = freshStreams?.hlsMaster ?? freshStreams?.hls720p;
      if (newUrl != null && newUrl.isNotEmpty) {
        _url = newUrl;
        await _openStream(_url);
      } else {
        final freshDetail = await _api.fetchDetail(_code);
        final fallbackUrl = freshDetail?.streams?.hlsMaster ?? freshDetail?.streams?.hls720p;
        if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
          _url = fallbackUrl;
          await _openStream(_url);
        } else {
          await _openStream(_url);
        }
      }
    } catch (_) {
      await _openStream(_url);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingStream = false);
      }
    }
  }

  void _switchToWebView() {
    if (_fallbackUrl.isNotEmpty) {
      Get.offNamed(
        '/jav/player',
        parameters: {
          'url': _fallbackUrl,
          'title': _title,
        },
      );
    } else {
      Get.back();
    }
  }

  Future<void> _changePlaybackRate(double rate) async {
    setState(() => _playbackRate = rate);
    await _player.setRate(rate);
  }

  void _showRatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('选择播放倍速'),
          actions: _availableRates.map((r) {
            final isSelected = (_playbackRate - r).abs() < 0.01;
            return CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                _changePlaybackRate(r);
              },
              child: Text(
                '${r}x ${isSelected ? '✓' : ''}',
                style: TextStyle(
                  color: isSelected ? Colors.cyanAccent : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.chevron_back, color: Colors.white),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 倍速切换
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _showRatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_playbackRate}x',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 网页线路降级入口
          if (_fallbackUrl.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: _switchToWebView,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.compass, color: Colors.white70, size: 16),
                  SizedBox(width: 2),
                  Text(
                    '网页线路',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          // 一键速退
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.redAccent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              onPressed: () =>
                  Get.offAllNamed('/main', arguments: {'initialIndex': 0}),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.redAccent, size: 13),
                  SizedBox(width: 3),
                  Text(
                    '速退',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 原生视频播放层
          Center(
            child: Video(
              controller: _videoController,
              controls: AdaptiveVideoControls,
            ),
          ),

          // 缓冲指示器
          if (_isBuffering && !_hasError && !_isRefreshingStream)
            const Center(
              child: CupertinoActivityIndicator(
                color: Colors.cyanAccent,
                radius: 18,
              ),
            ),

          // 刷新凭据等待状态
          if (_isRefreshingStream)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(
                      color: Colors.cyanAccent,
                      radius: 14,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '正在向服务端重新换取流凭证...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // 播放异常容错层
          if (_hasError)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: Colors.amberAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '流媒体直连播放失败',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : '流令牌可能已过期或受到了 CDN 防盗链限制',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoButton(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          onPressed: _retryWithFreshStream,
                          child: const Row(
                            children: [
                              Icon(
                                CupertinoIcons.arrow_clockwise,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '重试换链',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (_fallbackUrl.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          CupertinoButton(
                            color: Colors.cyanAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            onPressed: _switchToWebView,
                            child: const Row(
                              children: [
                                Icon(
                                  CupertinoIcons.compass,
                                  color: Colors.cyanAccent,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '切换网页播放',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
