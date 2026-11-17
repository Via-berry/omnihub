import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/pansou/services/pansou_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';

class PansouSettingsSheet extends StatefulWidget {
  const PansouSettingsSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PansouSettingsSheet(),
    );
  }

  @override
  State<PansouSettingsSheet> createState() => _PansouSettingsSheetState();
}

class _PansouSettingsSheetState extends State<PansouSettingsSheet> {
  late final TextEditingController _hostController;
  late final TextEditingController _tokenController;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final service = PansouService.to;
    _hostController = TextEditingController(text: service.host.value);
    _tokenController = TextEditingController(text: service.token.value);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    final service = PansouService.to;
    await service.updateConfig(
      newHost: _hostController.text.trim(),
      newToken: _tokenController.text.trim(),
    );
    final ok = await service.checkHealth();
    setState(() => _isTesting = false);

    if (ok) {
      ToastUtil.success('连接成功！PanSou 服务在线');
    } else {
      ToastUtil.error('连接失败，请检查服务地址或网络');
    }
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      ToastUtil.info('服务地址不能为空');
      return;
    }
    await PansouService.to.updateConfig(
      newHost: host,
      newToken: _tokenController.text.trim(),
    );
    ToastUtil.success('PanSou 配置已保存');
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.slider_horizontal_3, size: 18, color: Color(0xFF00E5FF)),
                  SizedBox(width: 8),
                  Text(
                    'PanSou 搜索服务设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(24, 24),
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.clear_circled_solid, size: 20, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '支持连接本地 NAS 或云端部署的 fish2018/pansou 服务',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 16),
          const Text(
            '服务 Host 地址',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _hostController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'http://192.168.50.81:8888',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'API 访问令牌 Token（可选）',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _tokenController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '若服务端开启 AUTH_ENABLED 时填写',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isTesting ? null : _testConnection,
                  child: _isTesting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          '测试连通',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFF00E5FF),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _save,
                  child: const Text(
                    '保存设置',
                    style: TextStyle(color: Color(0xFF11151F), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
