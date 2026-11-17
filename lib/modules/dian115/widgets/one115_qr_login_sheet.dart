import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviepilot_mobile/modules/dian115/services/one115_qr_login_service.dart';
import 'package:moviepilot_mobile/modules/dian115/services/pan115_service.dart';
import 'package:moviepilot_mobile/utils/toast_util.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 115 扫码登录弹窗：生成二维码 → 手机 115 App 扫码确认 → 换取并保存 Cookie
class One115QrLoginSheet extends StatefulWidget {
  const One115QrLoginSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const One115QrLoginSheet(),
    );
  }

  @override
  State<One115QrLoginSheet> createState() => _One115QrLoginSheetState();
}

class _One115QrLoginSheetState extends State<One115QrLoginSheet>
    with WidgetsBindingObserver {
  final One115QrLoginService _qrService = One115QrLoginService();

  One115DeviceProfile _profile = One115QrLoginService.defaultProfile;
  One115QrToken? _token;
  String _statusText = '正在获取二维码...';
  String _lastError = '';
  bool _isLoading = true;
  bool _isScanned = false;
  bool _isExchanging = false;
  bool _isExpired = false;
  bool _timedOut = false;
  int _refreshCount = 0;
  int _pollGen = 0;

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  int _remainSeconds = 0;

  /// 上一次轮询时间，用于判断轮询是否还活着
  DateTime? _lastPollAt;
  bool _lastPollOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLogin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLogin() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(One115QrLoginService.loginTimeout, () {
      if (!mounted || _isExchanging) return;
      _pollTimer?.cancel();
      setState(() {
        _timedOut = true;
        _isExpired = true;
        _statusText = '等待超时，请重新获取二维码';
      });
    });
    _refreshToken();
  }

  Future<void> _refreshToken() async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pollGen++;
    final gen = _pollGen;
    setState(() {
      _isLoading = true;
      _isExpired = false;
      _lastError = '';
      _timedOut = false;
      _isScanned = false;
      _statusText = '正在获取二维码...';
    });
    try {
      final token = await _qrService.fetchToken();
      if (!mounted || gen != _pollGen) return;
      setState(() {
        _token = token;
        _isLoading = false;
        _remainSeconds = One115QrLoginService.qrCodeTtl.inSeconds;
        _statusText = '请使用手机 115 App 扫码';
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remainSeconds--);
        if (_remainSeconds <= 0) t.cancel();
      });
      _schedulePoll(token, gen);
    } catch (e) {
      if (!mounted) return;
      final detail = e is One115QrException ? e.message : e.toString();
      setState(() {
        _isLoading = false;
        _isExpired = true;
        _lastError = detail.length > 80 ? '${detail.substring(0, 80)}...' : detail;
        _statusText = '二维码获取失败，点击重试';
      });
    }
  }

  void _schedulePoll(One115QrToken token, int gen) {
    _pollTimer?.cancel();
    _pollTimer = Timer(One115QrLoginService.pollInterval, () {
      _pollOnce(token, gen);
    });
  }

  /// 单次轮询 + 自调度。
  ///
  /// 不用 Timer.periodic：它的回调一旦抛出未捕获异常，定时器会被 Dart 静默取消，
  /// 之后轮询永久停摆（表现为"扫码确认后 app 毫无反应"）。改成每次自己排下一轮，
  /// 失败也不会停。gen 防止刷新二维码后旧票据的轮询抢回定时器。
  Future<void> _pollOnce(One115QrToken token, int gen) async {
    if (!mounted || _isExchanging || gen != _pollGen) return;
    try {
      final status = await _qrService.checkStatus(token);
      if (!mounted || gen != _pollGen) return;
      _markPolled(ok: true);
      switch (status.state) {
        case One115QrState.waiting:
          if (token.isExpired) {
            _onTokenExpired();
          }
          break;
        case One115QrState.scanned:
          if (!_isScanned) {
            setState(() {
              _isScanned = true;
              _statusText = '已扫码，请在手机上确认登录';
            });
          }
          break;
        case One115QrState.confirmed:
          _pollTimer?.cancel();
          await _exchange(token);
          break;
        case One115QrState.expired:
          _onTokenExpired();
          break;
      }
    } catch (_) {
      _markPolled(ok: false);
    } finally {
      if (mounted && gen == _pollGen && !_isExchanging && !_isExpired) {
        _schedulePoll(token, gen);
      }
    }
  }

  void _markPolled({required bool ok}) {
    if (!mounted) return;
    _lastPollAt = DateTime.now();
    _lastPollOk = ok;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS 上切到 115 App 扫码时本进程被挂起，Timer 不推进，确认动作会被漏掉。
    // 回到前台立刻补一次轮询。
    if (state != AppLifecycleState.resumed) return;
    final token = _token;
    if (token == null || _isLoading || _isExchanging || _isExpired) return;
    _schedulePoll(token, _pollGen);
  }

  void _onTokenExpired() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (_refreshCount >= One115QrLoginService.maxQrRefresh) {
      setState(() {
        _isExpired = true;
        _remainSeconds = 0;
        _statusText = '二维码已多次过期，请点击重新获取';
      });
      return;
    }
    _refreshCount++;
    setState(() {
      _isExpired = true;
      _remainSeconds = 0;
      _statusText = '二维码已过期，点击刷新';
    });
  }

  Future<void> _exchange(One115QrToken token) async {
    if (_isExchanging) return;
    setState(() {
      _isExchanging = true;
      _statusText = '已确认，正在登录...';
    });
    try {
      final result = await _qrService.exchangeForCookies(
        token.uid,
        _profile,
        One115QrLoginService.randomDeviceId(),
      );
      await Pan115Service.to.saveQrLoginCookie(result.cookieString);
      if (!mounted) return;
      ToastUtil.success('115 登录成功，凭证已更新');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExchanging = false;
        _statusText = '登录失败：$e，请重新扫码';
      });
      _refreshToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF11151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.qrcode,
                  size: 18,
                  color: Color(0xFF11151F),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '115 扫码登录',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '扫码成功后自动保存凭证用于转存',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.of(context).pop(false),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.clear,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 设备类型选择
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final p in One115QrLoginService.deviceProfiles.values) ...[
                _buildProfilePill(p),
                if (p.key != One115QrLoginService.deviceProfiles.keys.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 二维码区
          SizedBox(
            width: 220,
            height: 220,
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: Color(0xFF00E5FF),
                    ),
                  )
                : _token == null
                    ? _buildExpiredMask('获取失败', onTap: _refreshToken)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: _qrService.qrContent(_token!.uid),
                              version: QrVersions.auto,
                              size: 196,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          if (_isExpired) _buildExpiredMask(_timedOut ? '已超时' : '已过期'),
                        ],
                      ),
          ),
          const SizedBox(height: 14),

          // 状态文案 + 倒计时
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isScanned && !_isExchanging)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 14,
                    color: Color(0xFF34D399),
                  ),
                ),
              Flexible(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isExpired
                        ? const Color(0xFFF87171)
                        : Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_isExpired && _lastError.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _lastError,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF87171).withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
          if (!_isLoading && !_isExpired && _token != null) ...[
            const SizedBox(height: 6),
            Text(
              '二维码 ${_secondsLeft().clamp(0, 999)}s 后过期 · 当前身份：${_profile.label}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            _buildPollIndicator(),
          ],
        ],
      ),
    );
  }

  /// 用绝对时间算剩余秒数。倒计时 Timer 在切后台时会被挂起，
  /// 用 obtainedAt 算才不会在返回前台时显示错乱。
  int _secondsLeft() {
    final token = _token;
    if (token == null) return 0;
    return One115QrLoginService.qrCodeTtl.inSeconds -
        DateTime.now().difference(token.obtainedAt).inSeconds;
  }

  /// 轮询心跳。用户切到 115 App 扫码时本 app 被挂起，轮询会停；
  /// 这个指示器让人一眼看出是"没扫到"还是"检测没在跑"。
  Widget _buildPollIndicator() {
    final at = _lastPollAt;
    if (at == null) return const SizedBox.shrink();
    final ago = DateTime.now().difference(at).inSeconds;
    final bad = ago > 5 || !_lastPollOk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          bad
              ? CupertinoIcons.xmark_circle_fill
              : CupertinoIcons.checkmark_circle_fill,
          size: 9,
          color: bad ? const Color(0xFFF87171) : const Color(0xFF34D399),
        ),
        const SizedBox(width: 3),
        Text(
          bad ? '状态检测异常（${ago}s 前）' : '状态检测正常（${ago}s 前）',
          style: TextStyle(
            color: bad
                ? const Color(0xFFF87171).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePill(One115DeviceProfile p) {
    final selected = _profile.key == p.key;
    return GestureDetector(
      onTap: () {
        if (selected) return;
        setState(() {
          _profile = p;
          _refreshCount = 0;
        });
        _refreshToken();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF00E5FF) : Colors.transparent,
          ),
        ),
        child: Text(
          p.label,
          style: TextStyle(
            color: selected ? const Color(0xFF00E5FF) : Colors.white60,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredMask(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? _refreshToken,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.refresh, size: 28, color: Color(0xFF00E5FF)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 2),
            const Text(
              '点击重新获取',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
