import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 癫影账号移动端安全授权与网关会话续期弹窗
/// 依托手机真实移动端环境完成人机验证与登录，自动将提取到的最新会话回传至 NAS 网关
class Dian115LoginSheet extends StatefulWidget {
  const Dian115LoginSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const Dian115LoginSheet(),
    );
  }

  @override
  State<Dian115LoginSheet> createState() => _Dian115LoginSheetState();
}

class _Dian115LoginSheetState extends State<Dian115LoginSheet> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _statusText = '正在加载安全验证环境...';
  Timer? _authPoller;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  @override
  void dispose() {
    _authPoller?.cancel();
    super.dispose();
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
        'DianLoginBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleLoginMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _statusText = '正在连接登录页面...';
              });
            }
          },
          onPageFinished: (url) async {
            final uri = Uri.tryParse(url);
            final isLogin = uri != null &&
                (uri.path == '/login' || uri.path.endsWith('/login'));

            if (!isLogin) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _statusText = '登录成功，正在同步会话至网关...';
                });
              }
              await _triggerSync(isManual: false);
              return;
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
                _statusText = '请完成人机验证后，点击下方按钮登录';
              });
            }
            await _injectLoginHelper(controller);
            _startAuthPoller(controller);
          },
          onWebResourceError: (error) {
            debugPrint('Dian115 Login WebView error: ${error.description}');
          },
        ),
      );

    _webController = controller;
    await controller.loadRequest(Uri.parse('https://m.dian115.com/login'));
  }

  /// 注入自动填充脚本、排版优化及登录状态监听器
  Future<void> _injectLoginHelper(WebViewController controller) async {
    const helperJs = """
      (() => {
        // 1. 如果在登录页，先清理旧的本地会话数据，防止误触导致提前报错
        if (window.location.pathname.includes('/login')) {
          try {
            localStorage.removeItem('portal_user');
            sessionStorage.removeItem('portal_user');
          } catch(e) {}
        }

        // 2. 注入 CSS 确保网页容器可滚动，同时大幅缩小顶部海报留白，让登录框上移
        const style = document.createElement('style');
        style.innerHTML = `
          html, body, #portal-app, #app {
            overflow-y: auto !important;
            -webkit-overflow-scrolling: touch !important;
            height: auto !important;
            min-height: 100% !important;
          }
          /* 紧凑化顶部的巨大海报与多余留白 */
          img[src*="splash"], img[src*="backdrop"], div:has(> img[alt]) {
            max-height: 80px !important;
            object-fit: cover !important;
          }
          .relative.w-full.h-64, .relative.w-full.h-72, .relative.w-full.h-80 {
            height: 80px !important;
          }
          form, .space-y-4 {
            margin-bottom: 24px !important;
          }
        `;
        document.head.appendChild(style);

        // 3. 自动填充账号密码
        function fillInputs() {
          const emailInput = document.querySelector('input[type="email"]');
          const pwdInput = document.querySelector('input[type="password"]');
          if (emailInput && !emailInput.value) {
            emailInput.value = '215736296@qq.com';
            emailInput.dispatchEvent(new Event('input', { bubbles: true }));
            emailInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if (pwdInput && !pwdInput.value) {
            pwdInput.value = 'admin@@@';
            pwdInput.dispatchEvent(new Event('input', { bubbles: true }));
            pwdInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
        }
        fillInputs();
        setTimeout(fillInputs, 600);
        setTimeout(fillInputs, 1500);

        // 4. 自动轻微下滚，居中展示人机验证与登录按钮
        function scrollToLogin() {
          const btn = document.querySelector('button[type="submit"]') ||
                      Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('登录') || b.textContent.includes('登 录'));
          if (btn) {
            btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        }
        setTimeout(scrollToLogin, 700);

        // 5. 监听 Turnstile 验证完成
        let turnstileHandled = false;
        const turnstileWatcher = setInterval(() => {
          const respInput = document.querySelector('[name="cf-turnstile-response"]');
          if (respInput && respInput.value && respInput.value.length > 20 && !turnstileHandled) {
            turnstileHandled = true;
            clearInterval(turnstileWatcher);
            scrollToLogin();
            // 验证通过后 600ms 尝试自动触发网页的登录按钮
            setTimeout(() => {
              const btn = document.querySelector('button[type="submit"]') ||
                          Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('登录') || b.textContent.includes('登 录'));
              if (btn) {
                btn.click();
              }
            }, 600);
          }
        }, 400);

        // 6. 登录状态检测并通知 App
        function checkAndNotify() {
          try {
            const userStr = localStorage.getItem('portal_user');
            if (userStr && userStr !== 'null' && userStr !== '""') {
              DianLoginBridge.postMessage(JSON.stringify({
                event: 'login_success',
                user: JSON.parse(userStr),
                cookie: document.cookie || ''
              }));
              return true;
            }
          } catch(e) {}
          return false;
        }

        window.addEventListener('storage', (e) => {
          if (e.key === 'portal_user') checkAndNotify();
        });
      })();
    """;
    try {
      await controller.runJavaScript(helperJs);
    } catch (_) {}
  }

  /// 轮询检测是否已登录成功
  void _startAuthPoller(WebViewController controller) {
    _authPoller?.cancel();
    _authPoller = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isSyncing || !mounted) return;
      try {
        final res = await controller.runJavaScriptReturningResult(
          "localStorage.getItem('portal_user') || ''",
        );
        final raw = res.toString();
        if (raw.isNotEmpty && raw != 'null' && raw != '""') {
          _triggerSync(isManual: false);
        }
      } catch (_) {}
    });
  }

  void _handleLoginMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['event'] == 'login_success') {
        _triggerSync(
          userData: data['user'] as Map<String, dynamic>?,
          isManual: false,
        );
      }
    } catch (_) {}
  }

  /// 触发表单登录提交
  Future<void> _submitWebLogin() async {
    if (_isSyncing) return;
    setState(() {
      _statusText = '正在提交登录并同步网关...';
    });
    try {
      await _webController.runJavaScript("""
        (() => {
          const btn = document.querySelector('button[type="submit"]') ||
                      Array.from(document.querySelectorAll('button')).find(b => b.textContent.includes('登录') || b.textContent.includes('登 录'));
          if (btn) {
            btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
            btn.click();
            return;
          }
          const form = document.querySelector('form');
          if (form) {
            form.requestSubmit ? form.requestSubmit() : form.submit();
          }
        })();
      """);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_isSyncing) {
          _triggerSync(isManual: true);
        }
      });
    } catch (_) {}
  }

  /// 提取 Cookie 与用户数据并同步至 NAS 网关
  Future<void> _triggerSync({
    Map<String, dynamic>? userData,
    bool isManual = false,
  }) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _statusText = '已检测到登录会话，正在同步至 NAS 网关...';
    });

    try {
      Map<String, dynamic>? finalUserData = userData;
      if (finalUserData == null) {
        final res = await _webController.runJavaScriptReturningResult(
          "localStorage.getItem('portal_user') || ''",
        );
        String raw = res.toString();
        if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
          raw = jsonDecode(raw);
        }
        if (raw.isNotEmpty && raw != 'null' && raw != '""') {
          try {
            finalUserData = jsonDecode(raw) as Map<String, dynamic>?;
          } catch (_) {}
        }
      }

      final cookieResult = await _webController.runJavaScriptReturningResult(
        "document.cookie || ''",
      );
      String cookieStr = cookieResult.toString();
      if (cookieStr.startsWith('"') &&
          cookieStr.endsWith('"') &&
          cookieStr.length >= 2) {
        cookieStr = jsonDecode(cookieStr);
      }

      final cookieList = <Map<String, dynamic>>[];
      if (cookieStr.isNotEmpty) {
        final parts = cookieStr.split(';');
        for (final p in parts) {
          final trimmed = p.trim();
          if (trimmed.isEmpty) continue;
          final kv = trimmed.split('=');
          if (kv.length >= 2) {
            cookieList.add({
              'name': kv[0].trim(),
              'value': kv.sublist(1).join('=').trim(),
              'domain': 'm.dian115.com',
              'path': '/',
            });
          }
        }
      }

      final success = await Dian115Service.to.importSession(
        cookies: cookieList,
        userData: finalUserData,
        cookieString: cookieStr,
      );

      if (success) {
        _authPoller?.cancel();
        if (mounted) {
          ToastUtil.success('癫影会话授权成功！网关已恢复在线');
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _statusText = '网关会话同步未完成，请确认人机验证并通过登录';
          });
          if (isManual) {
            ToastUtil.error('同步网关失败，请先在下方完成登录');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusText = '同步异常: $e';
        });
        if (isManual) {
          ToastUtil.error('同步异常: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight =
        (mediaQuery.size.height - mediaQuery.padding.top - 12).clamp(520.0, 950.0);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF11151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.lock_shield_fill,
                        color: Color(0xFFFBBF24),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '癫影网关账号授权续期',
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
                    if (_isSyncing)
                      const CupertinoActivityIndicator(radius: 8)
                    else
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 26,
                        onPressed: () => _triggerSync(isManual: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '手动同步',
                            style: TextStyle(
                                color: Color(0xFFFBBF24), fontSize: 11),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 26,
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(CupertinoIcons.info_circle,
                    size: 12, color: Color(0xFFFBBF24)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '因官方安全防护机制，请轻触完成人机验证（绿勾），再点击下方一键提交登录。',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: _webController,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer()),
                    Factory<PanGestureRecognizer>(
                        () => PanGestureRecognizer()),
                    Factory<TapGestureRecognizer>(
                        () => TapGestureRecognizer()),
                  },
                ),
                if (_isLoading)
                  Container(
                    color: const Color(0xFF11151F),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 12),
                          SizedBox(height: 12),
                          Text(
                            '正在加载安全环境...',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isSyncing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 14),
                          SizedBox(height: 14),
                          Text(
                            '正在向 NAS 网关激活登录会话...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '同步完成后将自动恢复积分与片源',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 底部原生快捷登录操作栏
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, mediaQuery.padding.bottom + 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161C26),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _isSyncing ? null : () => _submitWebLogin(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSyncing)
                          const CupertinoActivityIndicator(color: Colors.black)
                        else ...[
                          const Icon(CupertinoIcons.arrow_right_circle_fill,
                              color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            '一键提交登录 (验证通过后点击)',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
