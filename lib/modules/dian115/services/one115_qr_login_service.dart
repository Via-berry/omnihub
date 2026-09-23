import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// 115 扫码登录协议客户端（Dart 移植自 F:\115scan\src\115-qr-login.mjs）
///
/// 协议流程：
///   ① GET  qrcodeapi.115.com/api/1.0/web/1.0/token  → {uid, time, sign}
///   ② 二维码内容 = https://115.com/scan/dg-{uid}（本地渲染，不拉官方 PNG）
///   ③ 轮询 GET qrcodeapi.115.com/get/status/?uid=&time=&sign=
///   ④ 确认后 POST passportapi.115.com/app/1.0/{channel}/{ver}/login/qrcode → cookie
///
/// 状态机：0=等待扫码 / 1=已扫码待确认 / 2=已确认 / -1,-2=失效需重新取票据
class One115QrLoginService {
  One115QrLoginService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
                  'Accept': 'application/json, text/plain, */*',
                },
              ),
            );

  final Dio _dio;

  static const String _qrApiHost = 'https://qrcodeapi.115.com';
  static const String _passportHost = 'https://passportapi.115.com';

  /// 官网硬编码：二维码 120s 过期
  static const Duration qrCodeTtl = Duration(seconds: 120);
  static const Duration pollInterval = Duration(milliseconds: 500);
  static const Duration loginTimeout = Duration(seconds: 300);
  static const int maxQrRefresh = 3;

  static const List<String> requiredCookieKeys = ['UID', 'CID', 'SEID'];

  static const Map<String, One115DeviceProfile> deviceProfiles = {
    'web': One115DeviceProfile(
      key: 'web',
      label: '网页端',
      channel: 'web',
      channelVer: '1.0',
      device: 'Web Browser',
      os: '10.0',
      version: '1.0',
      app: 'web',
    ),
    'android': One115DeviceProfile(
      key: 'android',
      label: '手机客户端',
      channel: 'android',
      channelVer: '5.0.1',
      device: 'Android',
      os: 'android',
      version: '8.0.20.0',
      app: 'android',
    ),
    'ios': One115DeviceProfile(
      key: 'ios',
      label: 'iOS 客户端',
      channel: 'ios',
      channelVer: '5.0.1',
      device: 'iPhone',
      os: '17.0',
      version: '8.0.20.0',
      app: 'ios',
    ),
    'tv': One115DeviceProfile(
      key: 'tv',
      label: '电视版',
      channel: 'tv',
      channelVer: '1.0',
      device: 'TV',
      os: '10.0',
      version: '1.0',
      app: 'tv',
    ),
  };

  static const One115DeviceProfile defaultProfile = One115DeviceProfile(
    key: 'web',
    label: '网页端',
    channel: 'web',
    channelVer: '1.0',
    device: 'Web Browser',
    os: '10.0',
    version: '1.0',
    app: 'web',
  );

  /// 16 字节随机 → 32 位 hex
  static String randomDeviceId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// ① 取二维码票据
  Future<One115QrToken> fetchToken() async {
    final resp = await _dio.get(
      '$_qrApiHost/api/1.0/web/1.0/token',
      options: Options(responseType: ResponseType.json),
    );
    final body = _asMap(resp.data);
    if (!isStateOk(body?['state'])) {
      throw One115QrException('token', '获取二维码票据失败: state=${body?['state']}');
    }
    final data = _asMap(body?['data']);
    final uid = data?['uid']?.toString() ?? '';
    final sign = data?['sign']?.toString() ?? '';
    final time = data?['time'];
    if (uid.isEmpty || sign.isEmpty || time == null) {
      throw One115QrException('token', '扫码票据无效：缺少 uid/time/sign');
    }
    return One115QrToken(
      uid: uid,
      time: time is int ? time : int.tryParse(time.toString()) ?? 0,
      sign: sign,
      obtainedAt: DateTime.now(),
    );
  }

  /// 二维码内容（深链）
  String qrContent(String uid) => 'https://115.com/scan/dg-$uid';

  /// ③ 查一次扫码状态
  Future<One115QrStatus> checkStatus(One115QrToken token) async {
    final resp = await _dio.get(
      '$_qrApiHost/get/status/',
      queryParameters: {
        'uid': token.uid,
        'time': token.time,
        'sign': token.sign,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(responseType: ResponseType.json),
    );
    final body = _asMap(resp.data);
    if (!isStateOk(body?['state'])) {
      // 票据无效（key invalid），需重新取票据
      return One115QrStatus.expired(message: body?['message']?.toString());
    }
    final data = _asMap(body?['data']);
    if (data == null || !data.containsKey('status')) {
      return const One115QrStatus.expired();
    }
    switch (data['status']) {
      case 0:
        return const One115QrStatus.waiting();
      case 1:
        return const One115QrStatus.scanned();
      case 2:
        return const One115QrStatus.confirmed();
      default:
        return One115QrStatus.expired(message: 'status=${data['status']}');
    }
  }

  /// ④ 用已确认的 key 换 cookie，返回完整 cookieString（保留全部键）
  Future<One115QrLoginResult> exchangeForCookies(
    String key,
    One115DeviceProfile profile,
    String deviceId,
  ) async {
    final resp = await _dio.post(
      '$_passportHost/app/1.0/${profile.channel}/${profile.channelVer}/login/qrcode',
      data: {
        'account': key,
        'passwd': key,
        'country': 'CN',
        'device': profile.device,
        'os': profile.os,
        'version': profile.version,
        'app': profile.app,
        'device_id': deviceId,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
    );
    final body = _asMap(resp.data);
    final data = _asMap(body?['data']);
    final cookie = _asMap(data?['cookie']);
    final ok = cookie != null &&
        requiredCookieKeys.every(
          (k) => (cookie[k]?.toString() ?? '').isNotEmpty,
        );
    if (!ok) {
      throw One115QrException(
        'exchange',
        '换 cookie 失败: ${body?['message'] ?? jsonEncode(body)}',
      );
    }
    final cookieString = cookie.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    return One115QrLoginResult(
      userId: (data?['user_id'] ?? data?['user_name'] ?? '').toString(),
      cookies: cookie.map((k, v) => MapEntry(k, v.toString())),
      cookieString: cookieString,
    );
  }

  /// 115 的 state 字段在不同端点可能是布尔 true 或数字 1
  static bool isStateOk(dynamic state) {
    if (state == true) return true;
    final s = state?.toString() ?? '';
    return s == '1' || s == 'true';
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
      } catch (_) {}
    }
    return null;
  }
}

class One115DeviceProfile {
  const One115DeviceProfile({
    required this.key,
    required this.label,
    required this.channel,
    required this.channelVer,
    required this.device,
    required this.os,
    required this.version,
    required this.app,
  });

  final String key;
  final String label;
  final String channel;
  final String channelVer;
  final String device;
  final String os;
  final String version;
  final String app;
}

class One115QrToken {
  const One115QrToken({
    required this.uid,
    required this.time,
    required this.sign,
    required this.obtainedAt,
  });

  final String uid;
  final int time;
  final String sign;
  final DateTime obtainedAt;

  bool get isExpired =>
      DateTime.now().difference(obtainedAt) > One115QrLoginService.qrCodeTtl;
}

enum One115QrState { waiting, scanned, confirmed, expired }

class One115QrStatus {
  const One115QrStatus._(this.state, {this.message});

  const One115QrStatus.waiting() : this._(One115QrState.waiting);
  const One115QrStatus.scanned() : this._(One115QrState.scanned);
  const One115QrStatus.confirmed() : this._(One115QrState.confirmed);
  const One115QrStatus.expired({String? message})
      : this._(One115QrState.expired, message: message);

  final One115QrState state;
  final String? message;
}

class One115QrLoginResult {
  const One115QrLoginResult({
    required this.userId,
    required this.cookies,
    required this.cookieString,
  });

  final String userId;
  final Map<String, String> cookies;
  final String cookieString;
}

class One115QrException implements Exception {
  const One115QrException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'One115QrException($code): $message';
}
