import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  @override
  void initState() {
    super.initState();
    final params = Get.parameters;
    final url = (params['url'] ?? '').trim();
    _title = params['title'] ?? '在线播放';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    if (url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(url));
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
          child: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
    );
  }
}
