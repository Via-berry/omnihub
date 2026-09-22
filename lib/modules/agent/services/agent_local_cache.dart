import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:moviepilot_mobile/modules/agent/models/agent_cache_models.dart';
import 'package:moviepilot_mobile/modules/agent/models/agent_models.dart';
import 'package:moviepilot_mobile/services/app_service.dart';
import 'package:moviepilot_mobile/services/hive_service.dart';

class AgentLocalCache {
  static const lastServerSessionKey = 'agent_last_server_session_id';
  static const lastClientSessionKey = 'agent_last_client_session_id';
  static const _keySeparator = '::';

  AgentLocalCache({
    Box<AgentSessionCache>? sessionBox,
    Box<AgentMessagesCacheEntry>? messagesBox,
    Box<String>? metaBox,
    String Function()? scopeKeyProvider,
  }) : _sessionBoxOverride = sessionBox,
       _messagesBoxOverride = messagesBox,
       _metaBoxOverride = metaBox,
       _scopeKeyProvider = scopeKeyProvider;

  final Box<AgentSessionCache>? _sessionBoxOverride;
  final Box<AgentMessagesCacheEntry>? _messagesBoxOverride;
  final Box<String>? _metaBoxOverride;
  final String Function()? _scopeKeyProvider;

  Box<AgentSessionCache> get _sessionBox =>
      _sessionBoxOverride ?? Get.find<HiveService>().agentSessionCacheBox;

  Box<AgentMessagesCacheEntry> get _messagesBox =>
      _messagesBoxOverride ?? Get.find<HiveService>().agentMessagesCacheBox;

  Box<String> get _metaBox =>
      _metaBoxOverride ?? Get.find<HiveService>().agentMetaCacheBox;

  bool get _usesAppScope =>
      _scopeKeyProvider == null && Get.isRegistered<AppService>();

  String get _scopeKey {
    final raw =
        _scopeKeyProvider?.call() ??
        (Get.isRegistered<AppService>()
            ? Get.find<AppService>().agentCacheScopeKey.value
            : '');
    return raw.trim();
  }

  bool get _canUseCache => !_usesAppScope || _scopeKey.isNotEmpty;

  String _scopedKey(String key) {
    final scope = _scopeKey;
    if (scope.isEmpty) return key;
    return '$scope$_keySeparator$key';
  }

  bool _matchesCurrentScope(dynamic key) {
    final text = key?.toString() ?? '';
    final scope = _scopeKey;
    if (scope.isEmpty) return !text.contains(_keySeparator);
    return text.startsWith('$scope$_keySeparator');
  }

  Future<List<AgentSession>> loadSessions() async {
    if (!_canUseCache || !_sessionBox.isOpen) return const [];
    return _sessionBox.keys
        .where(_matchesCurrentScope)
        .map(_sessionBox.get)
        .whereType<AgentSessionCache>()
        .map((item) => item.toModel())
        .toList(growable: false);
  }

  Future<void> saveSessions(List<AgentSession> sessions) async {
    if (!_canUseCache || sessions.isEmpty || !_sessionBox.isOpen) return;
    final keepKeys = <String>{};
    for (final session in sessions) {
      if (!_sessionBox.isOpen) return;
      final key = _scopedKey(session.sessionId);
      keepKeys.add(key);
      await _sessionBox.put(key, AgentSessionCache.fromModel(session));
    }
    if (!_sessionBox.isOpen) return;
    final staleKeys = _sessionBox.keys
        .where(_matchesCurrentScope)
        .map((key) => key.toString())
        .where((key) => !keepKeys.contains(key))
        .toList(growable: false);
    if (!_sessionBox.isOpen) return;
    await _sessionBox.deleteAll(staleKeys);
  }

  Future<List<AgentChatMessage>> loadMessages(String sessionKey) async {
    if (!_canUseCache || sessionKey.isEmpty || !_messagesBox.isOpen) return const [];
    final entry = _messagesBox.get(_scopedKey(sessionKey));
    if (entry == null || entry.messages.isEmpty) return const [];
    return entry.messages.map((item) => item.toModel()).toList(growable: false);
  }

  Future<void> saveMessages(
    String sessionKey,
    List<AgentChatMessage> messages,
  ) async {
    if (!_canUseCache || sessionKey.isEmpty || !_messagesBox.isOpen) return;
    final key = _scopedKey(sessionKey);
    if (messages.isEmpty) {
      await _messagesBox.delete(key);
      return;
    }
    await _messagesBox.put(
      key,
      AgentMessagesCacheEntry(
        messages: messages
            .map(AgentChatMessageCache.fromModel)
            .toList(growable: false),
      ),
    );
  }

  Future<void> migrateMessages(String fromKey, String toKey) async {
    if (!_canUseCache || fromKey.isEmpty || toKey.isEmpty || fromKey == toKey || !_messagesBox.isOpen) {
      return;
    }
    final scopedFromKey = _scopedKey(fromKey);
    final scopedToKey = _scopedKey(toKey);
    final entry = _messagesBox.get(scopedFromKey);
    if (entry == null || !_messagesBox.isOpen) return;
    await _messagesBox.put(scopedToKey, entry);
    if (!_messagesBox.isOpen) return;
    await _messagesBox.delete(scopedFromKey);
  }

  Future<void> saveLastSession({
    required String serverSessionId,
    required String clientSessionId,
  }) async {
    if (!_canUseCache || !_metaBox.isOpen) return;
    await _metaBox.put(_scopedKey(lastServerSessionKey), serverSessionId);
    if (!_metaBox.isOpen) return;
    await _metaBox.put(_scopedKey(lastClientSessionKey), clientSessionId);
  }

  Future<({String serverSessionId, String clientSessionId})?>
  loadLastSession() async {
    if (!_canUseCache || !_metaBox.isOpen) return null;
    final serverSessionId = _metaBox.get(_scopedKey(lastServerSessionKey));
    if (serverSessionId == null || serverSessionId.isEmpty) return null;
    return (
      serverSessionId: serverSessionId,
      clientSessionId: _metaBox.get(_scopedKey(lastClientSessionKey)) ?? '',
    );
  }
}
