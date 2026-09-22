import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviepilot_mobile/utils/open_url.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// WebView 页面，支持设置 Cookie
class WebViewScreen extends StatefulWidget {
  final String url;
  final String? cookie;

  const WebViewScreen({super.key, required this.url, this.cookie});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _cookieSet = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';

  // 点击事件回调
  void Function(String tagName, String? href, Map<String, dynamic>? data)?
  onWebViewClick;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url; // 初始化当前 URL
    _initializeWebView();
  }

  @override
  void dispose() {
    try {
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    super.dispose();
  }

  void _initializeWebView() async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            // 尽早更新 URL（页面开始加载时）
            setState(() {
              _currentUrl = url;
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            // 确保 URL 是最新的
            setState(() {
              _currentUrl = url;
            });

            // 如果使用 CookieManager 方式 cookie 没有生效，尝试使用 JavaScript 设置
            if (widget.cookie != null &&
                widget.cookie!.isNotEmpty &&
                !_cookieSet) {
              _cookieSet = await _setCookiesWithJavaScript(
                controller,
                widget.url,
                widget.cookie!,
              );
            }
            // 注入点击事件监听脚本
            await _injectClickListener(controller);
            // 更新导航状态
            _updateNavigationState();
            setState(() {
              _isLoading = false;
            });
          },
          // 拦截导航请求，可以获取链接点击（最早的 URL 变化时机）
          onNavigationRequest: (NavigationRequest request) {
            // 在导航请求时立即更新 URL（最早的时机）
            if (request.url != _currentUrl) {
              setState(() {
                _currentUrl = request.url;
              });
            }
            debugPrint('导航请求: ${request.url}');

            // 如果需要处理点击事件，可以在这里处理
            // 注意：这会拦截所有导航，如果需要允许导航，返回 NavigationDecision.navigate

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    // Android 平台特殊处理
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    // 如果有 cookie，先设置 cookie 再加载 URL
    if (widget.cookie != null && widget.cookie!.isNotEmpty) {
      _cookieSet = await _setCookiesWithCookieManager(widget.url, widget.cookie!);
    }

    // 加载 URL
    final uri = Uri.parse(widget.url);
    await controller.loadRequest(uri);
  }

  /// 使用 WebViewCookieManager 设置 Cookie（主要方式）
  Future<bool> _setCookiesWithCookieManager(
    String url,
    String cookieString,
  ) async {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;
      if (domain.isEmpty) return false;
      final cookieManager = WebViewCookieManager();

      // 解析 cookie 字符串（格式：key1=value1; key2=value2）
      final cookiePairs = cookieString.split(';');
      var written = 0;

      for (final pair in cookiePairs) {
        final trimmed = pair.trim();
        if (trimmed.isEmpty) continue;

        final keyValue = trimmed.split('=');
        if (keyValue.length >= 2) {
          final name = keyValue[0].trim();
          final value = keyValue.sublist(1).join('=').trim();

          // 同时写 host 与 dot-host，提升不同站点 cookie 命中率
          for (final d in [domain, '.$domain']) {
            await cookieManager.setCookie(
              WebViewCookie(name: name, value: value, domain: d, path: '/'),
            );
          }
          written += 1;
        }
      }

      debugPrint('已通过 CookieManager 设置 Cookie: $written 个');
      return written > 0;
    } catch (e) {
      debugPrint('通过 CookieManager 设置 Cookie 失败: $e');
      return false;
    }
  }

  /// 使用 JavaScript 设置 Cookie（备用方案）
  Future<bool> _setCookiesWithJavaScript(
    WebViewController controller,
    String url,
    String cookieString,
  ) async {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;

      // 解析 cookie 字符串（格式：key1=value1; key2=value2）
      final cookiePairs = cookieString.split(';');

      // 构建 JavaScript 代码来设置所有 cookie
      final cookieScripts = <String>[];

      for (final pair in cookiePairs) {
        final trimmed = pair.trim();
        if (trimmed.isEmpty) continue;

        final keyValue = trimmed.split('=');
        if (keyValue.length >= 2) {
          final key = keyValue[0].trim();
          final value = keyValue.sublist(1).join('=').trim();

          // 转义特殊字符
          final escapedKey = key.replaceAll("'", "\\'");
          final escapedValue = value.replaceAll("'", "\\'");

          // 先写无 domain，再写 domain，提高不同策略兼容性
          cookieScripts.add(
            "document.cookie = '$escapedKey=$escapedValue; path=/';",
          );
          if (domain.isNotEmpty) {
          cookieScripts.add(
            "document.cookie = '$escapedKey=$escapedValue; path=/; domain=$domain';",
          );
          }
        }
      }

      if (cookieScripts.isNotEmpty) {
        final script = cookieScripts.join('\n');
        await controller.runJavaScript(script);
        debugPrint('已通过 JavaScript 设置 Cookie: ${cookieScripts.length} 条');
        return true;
      }
    } catch (e) {
      debugPrint('通过 JavaScript 设置 Cookie 失败: $e');
      return false;
    }
    return false;
  }

  /// 注入点击事件监听脚本
  Future<void> _injectClickListener(WebViewController controller) async {
    // 注入 JavaScript 代码来监听点击事件
    const script = '''
      (function() {
        // 移除之前的事件监听器（如果存在）
        if (window._flutterWebViewClickListener) {
          document.removeEventListener('click', window._flutterWebViewClickListener, true);
          window.removeEventListener('click', window._flutterWebViewClickListener, true);
        }
        
        // 创建新的点击事件监听器
        window._flutterWebViewClickListener = function(event) {
          try {
            var target = event.target || event.srcElement;
            var tagName = (target.tagName || '').toLowerCase();
            var href = null;
            var data = {};
            
            // 获取链接地址
            var linkElement = target;
            if (tagName !== 'a') {
              linkElement = target.closest('a');
            }
            if (linkElement) {
              href = linkElement.href || linkElement.getAttribute('href') || null;
            }
            
            // 获取其他有用的数据
            var text = target.innerText || target.textContent || '';
            data = {
              id: target.id || '',
              className: target.className || '',
              text: text.substring(0, 100),
              x: event.clientX || 0,
              y: event.clientY || 0,
            };
            
            // 存储到全局变量
            var clickEvent = {
              tagName: tagName,
              href: href,
              data: data,
              timestamp: Date.now()
            };
            
            window._lastClickEvent = clickEvent;
            
            // 输出到控制台（用于调试）
            console.log('[WebView点击事件]', JSON.stringify(clickEvent));
            
            // 标记有新点击事件
            window._hasNewClickEvent = true;
          } catch (e) {
            console.error('[点击事件处理错误]', e);
          }
        };
        
        // 添加事件监听器（使用捕获阶段以确保捕获所有点击）
        document.addEventListener('click', window._flutterWebViewClickListener, true);
        window.addEventListener('click', window._flutterWebViewClickListener, true);
        
        // 初始化标志
        window._hasNewClickEvent = false;
        window._lastClickEvent = null;
        
        console.log('[WebView] 点击事件监听器已安装');
      })();
    ''';

    try {
      await controller.runJavaScript(script);
      debugPrint('✅ 已注入点击事件监听脚本');

      // 启动定时器检查点击事件
      _startClickEventMonitor();
    } catch (e) {
      debugPrint('❌ 注入点击事件监听脚本失败: $e');
    }
  }

  /// 启动点击事件监控（定期检查）
  void _startClickEventMonitor() {
    // 使用 Future.delayed 定期检查
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      try {
        // 检查是否有新的点击事件
        final hasNew = await _controller.runJavaScriptReturningResult(
          'window._hasNewClickEvent || false',
        );

        if (hasNew.toString() == 'true') {
          // 获取点击事件
          final clickEvent = await getLastClickEvent();
          if (clickEvent != null) {
            debugPrint('🔔 检测到点击事件: ${clickEvent['raw']}');

            // 重置标志
            await _controller.runJavaScript(
              'window._hasNewClickEvent = false;',
            );

            // 调用回调
            if (onWebViewClick != null) {
              // 这里可以解析 JSON 并调用回调
            }
          }
        }
      } catch (e) {
        debugPrint('检查点击事件失败: $e');
      }

      // 继续监控
      if (mounted) {
        _startClickEventMonitor();
      }
    });
  }

  /// 获取最后一次点击事件（通过 JavaScript 查询）
  /// 使用示例：在需要获取点击事件时调用此方法
  Future<Map<String, dynamic>?> getLastClickEvent() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window._lastClickEvent || null)',
      );
      final resultStr = result.toString();
      if (resultStr != 'null' && resultStr.isNotEmpty) {
        // 解析 JSON 字符串
        // 注意：这里需要根据实际返回格式处理
        debugPrint('最后点击事件: $resultStr');
        return {'raw': resultStr};
      }
    } catch (e) {
      debugPrint('获取点击事件失败: $e');
    }
    return null;
  }

  /// 更新导航状态（是否可以后退/前进）
  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  /// 后退
  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      _updateNavigationState();
    }
  }

  /// 前进
  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
      _updateNavigationState();
    }
  }

  /// 关闭页面
  void _close() {
    Navigator.of(context).pop();
  }

  String _currentLink() => _currentUrl.isNotEmpty ? _currentUrl : widget.url;

  String _hostLabel(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.host.isNotEmpty) return uri.host;
      return rawUrl;
    } catch (_) {
      return rawUrl;
    }
  }

  Future<void> _reloadOrStop() async {
    if (_isLoading) {
      await _controller.runJavaScript('window.stop();');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await _updateNavigationState();
      return;
    }
    await _controller.reload();
  }

  Future<void> _copyCurrentLink() async {
    final text = _currentLink();
    await Clipboard.setData(ClipboardData(text: text));
    ToastUtil.success('链接已复制');
  }

  Future<void> _openExternalBrowser() async {
    await WebUtil.open(url: _currentLink());
  }

  Widget _buildToolbarIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool enabled = true,
    bool accent = false,
  }) {
    final theme = Theme.of(context);
    final activeColor = accent
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.28);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? activeColor : inactiveColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafariToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final current = _currentLink();
    final host = _hostLabel(current);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _copyCurrentLink,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.14),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock_shield,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.doc_on_doc,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildToolbarIcon(
                      context,
                      icon: CupertinoIcons.xmark,
                      tooltip: '关闭',
                      onTap: _close,
                      accent: true,
                    ),
                    _buildToolbarIcon(
                      context,
                      icon: CupertinoIcons.back,
                      tooltip: '后退',
                      onTap: _goBack,
                      enabled: _canGoBack,
                    ),
                    _buildToolbarIcon(
                      context,
                      icon: CupertinoIcons.forward,
                      tooltip: '前进',
                      onTap: _goForward,
                      enabled: _canGoForward,
                    ),
                    _buildToolbarIcon(
                      context,
                      icon: _isLoading
                          ? CupertinoIcons.xmark_circle
                          : CupertinoIcons.refresh,
                      tooltip: _isLoading ? '停止加载' : '刷新',
                      onTap: _reloadOrStop,
                    ),
                    _buildToolbarIcon(
                      context,
                      icon: CupertinoIcons.compass,
                      tooltip: '浏览器打开',
                      onTap: _openExternalBrowser,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    return Scaffold(
      // iOS 设备上移除 AppBar
      appBar: isIOS
          ? null
          : AppBar(
              title: const Text('网页浏览'),
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
      body: Stack(
        children: [
          // WebView - iOS 上使用 SafeArea
          isIOS
              ? SafeArea(
                  bottom: false,
                  top: false,
                  child: WebViewWidget(controller: _controller),
                )
              : WebViewWidget(controller: _controller),
          // // 加载指示器
          // if (_isLoading)
          //   const Center(
          //     child: CircularProgressIndicator(),
          //   ),
          // 底部按钮区域 - 带渐变模糊背景，延伸到 safe area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSafariToolbar(context),
          ),
        ],
      ),
    );
  }
}
