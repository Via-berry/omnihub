import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JavPlayerPage extends StatefulWidget {
  const JavPlayerPage({super.key});

  @override
  State<JavPlayerPage> createState() => _JavPlayerPageState();
}

class _JavPlayerPageState extends State<JavPlayerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _title = '在线播放';
  String _initialUrl = '';
  String _allowedHost = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  static const String _adBlockScript = '''
(function() {
  // 1. 禁用任何弹窗与新窗口劫持
  window.open = function() { return null; };
  window.alert = function() {};
  window.confirm = function() { return false; };

  // 2. 移除点击劫持 target="_blank"
  function sanitizeLinks() {
    var links = document.querySelectorAll('a[target="_blank"]');
    for (var i = 0; i < links.length; i++) {
      links[i].removeAttribute('target');
    }
  }
  sanitizeLinks();
  setInterval(sanitizeLinks, 1000);

  // 3. 强制 iOS 网页内直接播放，禁止脱离行内
  function forceInlinePlayback() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      videos[i].setAttribute('playsinline', 'true');
      videos[i].setAttribute('webkit-playsinline', 'true');
    }
  }
  forceInlinePlayback();
  setInterval(forceInlinePlayback, 1000);
})();
''';

  @override
  void initState() {
    super.initState();
    final params = Get.parameters;
    _initialUrl = (params['url'] ?? '').trim();
    _title = params['title'] ?? '在线播放';

    final uri = Uri.tryParse(_initialUrl);
    if (uri != null && uri.host.isNotEmpty) {
      _allowedHost = uri.host.toLowerCase();
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _controller.runJavaScript(_adBlockScript);
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final canBack = await _controller.canGoBack();
              final canForward = await _controller.canGoForward();
              setState(() {
                _isLoading = false;
                _canGoBack = canBack;
                _canGoForward = canForward;
              });
            }
            _controller.runJavaScript(_adBlockScript);
          },
          onNavigationRequest: (NavigationRequest request) {
            final targetUri = Uri.tryParse(request.url);
            if (targetUri == null) {
              return NavigationDecision.prevent;
            }

            final scheme = targetUri.scheme.toLowerCase();
            if (scheme == 'about' || scheme == 'data') {
              return NavigationDecision.navigate;
            }

            // 拦截非 http/https 唤醒外链 (如 app 推广、itms-appss:)
            if (scheme != 'http' && scheme != 'https') {
              return NavigationDecision.prevent;
            }

            final targetHost = targetUri.host.toLowerCase();

            // 允许当前主站域名与视频流切片 CDN 域名放行
            final isAllowed = _allowedHost.isEmpty ||
                targetHost == _allowedHost ||
                targetHost.endsWith('.$_allowedHost') ||
                _allowedHost.endsWith(targetHost) ||
                targetHost.contains('missav') ||
                targetHost.contains('jable') ||
                targetHost.contains('dmm.co.jp') ||
                targetHost.contains('surrit') ||
                targetHost.contains('sixyik') ||
                targetHost.contains('mushroomtrack') ||
                targetHost.contains('cloudflare') ||
                targetHost.contains('turnstile') ||
                targetHost.contains('hcaptcha');

            if (isAllowed) {
              return NavigationDecision.navigate;
            }

            // 其余外部广告域名跳转一律强行阻断
            debugPrint('Blocked ad redirect to: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      );

    if (_initialUrl.isNotEmpty) {
      _controller.loadRequest(Uri.parse(_initialUrl));
    }
  }

  @override
  void dispose() {
    // 销毁时停止音视频播放与执行，释放资源
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  Future<void> _openInSafari() async {
    final currentUrl = await _controller.currentUrl() ?? _initialUrl;
    if (currentUrl.isNotEmpty) {
      final u = Uri.tryParse(currentUrl);
      if (u != null) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Get.back(),
          child: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 22),
        ),
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 一键速退
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: Colors.redAccent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              onPressed: () => Get.offAllNamed('/main', arguments: {'initialIndex': 0}),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.redAccent, size: 14),
                  SizedBox(width: 4),
                  Text('一键速退', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CupertinoActivityIndicator(color: Colors.cyanAccent, radius: 16),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF101010),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4,
          top: 6,
          left: 12,
          right: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: _canGoBack
                      ? () async {
                          await _controller.goBack();
                          final canBack = await _controller.canGoBack();
                          final canForward = await _controller.canGoForward();
                          if (mounted) setState(() { _canGoBack = canBack; _canGoForward = canForward; });
                        }
                      : null,
                  child: Icon(
                    CupertinoIcons.chevron_back,
                    color: _canGoBack ? Colors.white : Colors.white24,
                    size: 20,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: _canGoForward
                      ? () async {
                          await _controller.goForward();
                          final canBack = await _controller.canGoBack();
                          final canForward = await _controller.canGoForward();
                          if (mounted) setState(() { _canGoBack = canBack; _canGoForward = canForward; });
                        }
                      : null,
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    color: _canGoForward ? Colors.white : Colors.white24,
                    size: 20,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () => _controller.reload(),
                  child: const Icon(CupertinoIcons.arrow_clockwise, color: Colors.white70, size: 18),
                ),
              ],
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              onPressed: _openInSafari,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.compass, color: Colors.cyanAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Safari 打开',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
