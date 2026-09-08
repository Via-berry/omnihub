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
/// 依托手机原生 WebView 与真实移动网络环境，直接在官方有效页面中调用 Cloudflare Turnstile 验证
class Dian115VerifySheet extends StatefulWidget {
  const Dian115VerifySheet({
    super.key,
    required this.item,
    this.tmdbId,
    this.mediaType = 'movie',
    this.season = 0,
  });

  final Dian115ShareItem item;
  final int? tmdbId;
  final String mediaType;
  final int? season;

  /// 计算癫影标准影视资源 Key
  static String generateResourceKey({
    required String mediaType,
    required int tmdbId,
    int season = 0,
  }) {
    const xorKeys = [55, 161, 92, 233];
    final type = mediaType.toLowerCase() == 'tv' ? 'tv' : 'movie';
    final rawStr = '1|tmdb|$type|$tmdbId|$season';
    final rawBytes = utf8.encode(rawStr);
    final xored = List<int>.generate(
      rawBytes.length,
      (i) => rawBytes[i] ^ xorKeys[i % xorKeys.length],
    );
    final b64 = base64.encode(xored);
    return b64.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }

  static Future<Dian115UnlockResult?> show(
    BuildContext context, {
    required Dian115ShareItem item,
    int? tmdbId,
    String mediaType = 'movie',
    int? season,
  }) {
    return showModalBottomSheet<Dian115UnlockResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Dian115VerifySheet(
        item: item,
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
      ),
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
                _statusText = '请轻触下方复选框完成人机验证';
              });
            }
            await _injectTurnstileScript(controller);
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

    // 确定合法的官方页面 URL：优先使用该影视的真实资源详情页 /r/{key}，无 TMDB ID 时使用首页 /
    String targetUrl;
    if (widget.tmdbId != null && widget.tmdbId! > 0) {
      final key = Dian115VerifySheet.generateResourceKey(
        mediaType: widget.mediaType,
        tmdbId: widget.tmdbId!,
        season: widget.season ?? 0,
      );
      targetUrl = 'https://m.dian115.com/r/$key';
    } else {
      targetUrl = 'https://m.dian115.com/';
    }

    await controller.loadRequest(Uri.parse(targetUrl));
    _webController = controller;
  }

  Future<void> _injectTurnstileScript(WebViewController controller) async {
    const script = '''
(() => {
  if (window.__dian_turnstile_injected) return;
  window.__dian_turnstile_injected = true;

  function notifyApp(payload) {
    if (window.DianUnlockBridge) {
      window.DianUnlockBridge.postMessage(JSON.stringify(payload));
    }
  }

  // 1. 创建全屏居中的优雅暗黑验证卡片
  let box = document.getElementById("dian115_turnstile_box");
  if (!box) {
    box = document.createElement("div");
    box.id = "dian115_turnstile_box";
    box.style.position = "fixed";
    box.style.top = "0";
    box.style.left = "0";
    box.style.width = "100vw";
    box.style.height = "100vh";
    box.style.zIndex = "2147483647";
    box.style.background = "rgba(17, 21, 31, 0.98)";
    box.style.display = "flex";
    box.style.flexDirection = "column";
    box.style.alignItems = "center";
    box.style.justifyContent = "center";
    box.style.padding = "24px";
    box.style.boxSizing = "border-box";
    box.style.fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";

    box.innerHTML = `
      <div style="width: 48px; height: 48px; border-radius: 14px; background: rgba(16, 185, 129, 0.16); border: 1px solid rgba(16, 185, 129, 0.35); display: flex; align-items: center; justify-content: center; margin-bottom: 14px;">
        <span style="font-size: 24px;">🛡️</span>
      </div>
      <div style="color: #ffffff; font-size: 16px; font-weight: 800; margin-bottom: 6px;">癫影安全人机验证</div>
      <div style="color: #94a3b8; font-size: 12px; margin-bottom: 22px; text-align: center; line-height: 1.4;">请轻触下方复选框完成验证<br/>验证通过后将自动解锁并转存</div>
      <div id="dian115_widget_mount" style="min-height: 65px; display: flex; justify-content: center;"></div>
      <div id="dian115_verify_hint" style="color: #64748b; font-size: 11px; margin-top: 18px;">等待验证响应中...</div>
    `;
    document.body.appendChild(box);
  }

  function mountTurnstile() {
    if (!window.turnstile) return false;
    const mountElem = document.getElementById("dian115_widget_mount");
    if (!mountElem) return false;
    if (window.__current_widget_id !== undefined) return true;

    try {
      const widgetId = window.turnstile.render(mountElem, {
        sitekey: "0x4AAAAAADi7p3XK5mZ5PKSv",
        action: "portal_unlock",
        theme: "dark",
        language: "zh-CN",
        callback: function(token) {
          const hint = document.getElementById("dian115_verify_hint");
          if (hint) hint.innerText = "验证通过！正在提交解锁并转存...";
          notifyApp({ type: "token", token: token });
        },
        "error-callback": function(err) {
          const hint = document.getElementById("dian115_verify_hint");
          if (hint) hint.innerText = "验证未成功，请轻触重试";
        }
      });
      window.__current_widget_id = widgetId;
      return true;
    } catch(e) {
      return false;
    }
  }

  if (!window.turnstile) {
    const s = document.createElement("script");
    s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    s.async = true;
    s.onload = function() {
      setTimeout(mountTurnstile, 150);
    };
    document.head.appendChild(s);
  } else {
    mountTurnstile();
  }

  // 备用监听器：拦截原页面的 fetch 与 DOM
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
})();
''';

    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('注入验证拦截脚本异常: $e');
    }
  }

  Future<void> _handleUnlockedMessage(String rawJson) async {
    if (_isUnlockedCaptured) return;
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;

      // 分支一：捕获到 Turnstile 验证 Token，立即调用网关解锁
      if (data['type'] == 'token' && data['token'] != null) {
        final token = data['token'].toString();
        if (mounted) {
          setState(() {
            _statusText = '验证通过！正在通知网关完成解锁...';
          });
        }
        final unlockResult = await Dian115Service.to.unlockShare(
          widget.item.id,
          turnstileToken: token,
        );
        if (unlockResult.isSuccess) {
          _isUnlockedCaptured = true;
          HapticFeedback.heavyImpact();
          ToastUtil.success('安全验证通过！片源已成功解锁');
          if (mounted) {
            Navigator.of(context).pop(unlockResult);
          }
        } else {
          ToastUtil.error('解锁未成功：${unlockResult.code}');
        }
        return;
      }

      // 分支二：捕获到已解锁的资源链接
      final result = Dian115UnlockResult.fromJson(data);
      if (result.isSuccess) {
        _isUnlockedCaptured = true;
        HapticFeedback.heavyImpact();
        ToastUtil.success('安全验证通过！片源已就绪');
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      debugPrint('处理验证通知失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.75;

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
                            '正在接入安全校验环境...',
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
