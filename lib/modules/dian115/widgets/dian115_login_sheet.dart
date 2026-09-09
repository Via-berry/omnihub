import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/dian115/services/dian115_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 癫影账号移动端安全授权与网关会话续期弹窗
/// 依托手机真实移动端环境完成人机验证与登录，自动将提取到的最新会话回传至 NAS 网关
class Dian115LoginSheet extends StatefulWidget {
  const Dian115LoginSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
            if (mounted) {
              setState(() {
                _isLoading = false;
                _statusText = '请在下方轻触完成人机验证并登录';
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

  /// 注入自动填充脚本及登录状态监听器
  Future<void> _injectLoginHelper(WebViewController controller) async {
    const helperJs = """
      (() => {
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
        setTimeout(fillInputs, 800);

        function checkAndNotify() {
          try {
            const userStr = localStorage.getItem('portal_user');
            if (userStr) {
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

        if (!checkAndNotify()) {
          window.addEventListener('storage', (e) => {
            if (e.key === 'portal_user') checkAndNotify();
          });
        }
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
          timer.cancel();
          _triggerSync();
        }
      } catch (_) {}
    });
  }

  void _handleLoginMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['event'] == 'login_success') {
        _triggerSync(userData: data['user'] as Map<String, dynamic>?);
      }
    } catch (_) {}
  }

  /// 提取 Cookie 与用户数据并同步至 NAS 网关
  Future<void> _triggerSync({Map<String, dynamic>? userData}) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _statusText = '已检测到登录成功，正在同步网关会话...';
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
        if (raw.isNotEmpty && raw != 'null') {
          finalUserData = jsonDecode(raw) as Map<String, dynamic>?;
        }
      }

      final cookieResult = await _webController.runJavaScriptReturningResult(
        "document.cookie || ''",
      );
      String cookieStr = cookieResult.toString();
      if (cookieStr.startsWith('"') && cookieStr.endsWith('"') && cookieStr.length >= 2) {
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
        if (mounted) {
          ToastUtil.success('癫影会话授权成功！网关已恢复在线');
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _statusText = '同步网关失败，请确认网关是否正常运行';
          });
          ToastUtil.error('会话同步至网关失败，请重试');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusText = '发生异常: $e';
        });
        ToastUtil.error('同步异常: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

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
                        onPressed: () => _triggerSync(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '手动同步',
                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
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
                Icon(CupertinoIcons.info_circle, size: 12, color: Color(0xFFFBBF24)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '因官方安全防护机制，请在下方轻触完成人机验证并点击登录，成功后将全自动激活网关。',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
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
                          CupertinoActivityIndicator(radius: 12),
                          SizedBox(height: 12),
                          Text(
                            '正在加载安全环境...',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
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
                            style: TextStyle(color: Colors.white54, fontSize: 11),
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
