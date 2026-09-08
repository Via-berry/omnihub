import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviepilot_mobile/modules/dian115/models/dian115_models.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 癫影资源原生安全验证与解锁弹窗
/// 依托手机原生 WebView 与真实移动网络环境，无缝通过 Cloudflare Turnstile 验证并自动捕获解锁链接
class Dian115VerifySheet extends StatefulWidget {
  const Dian115VerifySheet({
    super.key,
    required this.item,
  });

  final Dian115ShareItem item;

  static Future<Dian115UnlockResult?> show(
    BuildContext context, {
    required Dian115ShareItem item,
  }) {
    return showModalBottomSheet<Dian115UnlockResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Dian115VerifySheet(item: item),
    );
  }

  @override
  State<Dian115VerifySheet> createState() => _Dian115VerifySheetState();
}

class _Dian115VerifySheetState extends State<Dian115VerifySheet> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _isUnlockedCaptured = false;
  String _statusText = '正在加载安全验证环境...';

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  Future<void> _initWebViewController() async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF11151F))
      ..addJavaScriptChannel(
        'DianUnlockBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleUnlockedMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _statusText = '正在连接片源页面...';
              });
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _statusText = '请在下方轻触“解锁并查看”或完成人机验证';
              });
            }
            await _injectUnlockInterceptor(controller);
          },
          onWebResourceError: (error) {
            debugPrint('Dian115 WebView resource error: ${error.description}');
          },
        ),
      );

    // 预注入当前服务端的有效登录 Cookie
    try {
      final cookieManager = WebViewCookieManager();
      final authData = await Dian115Service.to.getAuthCookies();
      final cookieString = authData['cookie_string']?.toString() ?? '';
      if (cookieString.isNotEmpty) {
        final pairs = cookieString.split(';');
        for (final pair in pairs) {
          final trimmed = pair.trim();
          if (trimmed.isEmpty) continue;
          final kv = trimmed.split('=');
          if (kv.length >= 2) {
            final name = kv[0].trim();
            final value = kv.sublist(1).join('=').trim();
            for (final d in ['m.dian115.com', '.dian115.com']) {
              await cookieManager.setCookie(
                WebViewCookie(name: name, value: value, domain: d, path: '/'),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('设置 WebView Cookie 异常: $e');
    }

    final targetUrl = 'https://m.dian115.com/share/${widget.item.id}';
    await controller.loadRequest(Uri.parse(targetUrl));
    _webController = controller;
  }

  Future<void> _injectUnlockInterceptor(WebViewController controller) async {
    const interceptorJs = '''
(() => {
  if (window.__dian_interceptor_injected) return;
  window.__dian_interceptor_injected = true;

  function notifyApp(payload) {
    if (window.DianUnlockBridge) {
      window.DianUnlockBridge.postMessage(JSON.stringify(payload));
    }
  }

  // 1. 拦截 fetch 请求
  const origFetch = window.fetch;
  window.fetch = async function(...args) {
    const response = await origFetch.apply(this, args);
    try {
      const url = typeof args[0] === 'string' ? args[0] : (args[0] && args[0].url) || '';
      if (url.includes('/unlock') || url.includes('/portal')) {
        const clone = response.clone();
        clone.json().then(data => {
          if (data && data.ok && data.data) {
            notifyApp({
              code: 'ok',
              share_url: data.data.share_url || '',
              receive_code: data.data.receive_code || '',
              magnet_url: data.data.magnet_url || '',
              points_cost: data.data.points_cost || 0
            });
          }
        }).catch(() => {});
      }
    } catch(e) {}
    return response;
  };

  // 2. 轮询 DOM 提取已解锁的链接与提取码
  function scanPageLinks() {
    const text = document.body ? document.body.innerText : '';
    if (!text) return false;

    const m115 = text.match(/https?:\\/\\/115\\.com\\/s\\/([a-zA-Z0-9]+)/) ||
                 text.match(/115\\.com\\/s\\/([a-zA-Z0-9]+)/);
    const mCode = text.match(/(?:提取码|访问码|密码)[：:\\s]*([a-zA-Z0-9]{4})/i);
    const mMagnet = text.match(/(magnet:\\?xt=urn:btih:[a-zA-Z0-9]+[^\\s"']*)/i);

    if (m115 || mMagnet) {
      notifyApp({
        code: 'ok',
        share_url: m115 ? (m115[0].startsWith('http') ? m115[0] : 'https://' + m115[0]) : '',
        receive_code: mCode ? mCode[1] : '',
        magnet_url: mMagnet ? mMagnet[0] : '',
        points_cost: 0
      });
      return true;
    }
    return false;
  }

  setInterval(scanPageLinks, 1000);

  // 3. 自动滚动到页面下方展示解锁交互按钮
  setTimeout(() => {
    window.scrollTo({ top: document.body.scrollHeight / 2, behavior: 'smooth' });
  }, 1200);
})();
''';

    try {
      await controller.runJavaScript(interceptorJs);
    } catch (e) {
      debugPrint('注入验证拦截脚本异常: $e');
    }
  }

  void _handleUnlockedMessage(String rawJson) {
    if (_isUnlockedCaptured) return;
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final result = Dian115UnlockResult.fromJson(data);
      if (result.isSuccess) {
        _isUnlockedCaptured = true;
        HapticFeedback.heavyImpact();
        ToastUtil.success('安全验证通过！资源已就绪');
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      debugPrint('解析解锁通知失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.82;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF11151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 顶部手柄与标题栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161C26),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.shield_lefthalf_fill,
                        color: Color(0xFF34D399),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '癫影安全校验与解锁',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 26,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.clear,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 提示条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle,
                  size: 12,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '若提示 Turnstile 验证码，在页面轻触勾选即可。解锁完成后将自动关闭并开始转存。',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // WebView 主体内容
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webController),
                if (_isLoading)
                  Container(
                    color: const Color(0xFF11151F),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 12,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '正在接入癫影移动安全通道...',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
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
