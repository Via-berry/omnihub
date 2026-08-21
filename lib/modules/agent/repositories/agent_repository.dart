import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:moviepilot_mobile/modules/agent/models/agent_models.dart';
import 'package:moviepilot_mobile/modules/agent/utils/agent_sse_logger.dart';
import 'package:moviepilot_mobile/services/api_client.dart';

abstract class AgentRepositoryContract {
  Future<List<AgentSession>> fetchSessions({int page = 1, int count = 30});

  Future<List<AgentChatMessage>> fetchSessionMessages(String sessionId);

  Future<Stream<AgentStreamEvent>> sendMessage({
    required String text,
    required String sessionId,
    String? clientSessionId,
  });
}

class AgentRepository implements AgentRepositoryContract {
  AgentRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? Get.find<ApiClient>();

  final ApiClient _apiClient;

  @override
  Future<List<AgentSession>> fetchSessions({
    int page = 1,
    int count = 30,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/message/agent/sessions',
      queryParameters: {'page': page, 'count': count},
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => AgentSession.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }
    if (data is! Map || data['success'] != true) {
      final message = data is Map ? data['message']?.toString() : null;
      throw StateError(message ?? '会话列表加载失败');
    }
    final list = data['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => AgentSession.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<AgentChatMessage>> fetchSessionMessages(String sessionId) async {
    final encodedSessionId = Uri.encodeComponent(sessionId);
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/message/agent/sessions/$encodedSessionId',
    );
    final data = response.data;
    if (data == null || data['success'] != true) {
      throw StateError(data?['message']?.toString() ?? '历史消息加载失败');
    }
    final sessionData = data['data'];
    if (sessionData is! Map) return const [];
    final messages = sessionData['messages'];
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map(
          (item) => AgentChatMessage.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<Stream<AgentStreamEvent>> sendMessage({
    required String text,
    required String sessionId,
    String? clientSessionId,
  }) async {
    final logger = AgentSseLogger();
    logger.logStreamStart(sessionId: sessionId, textLength: text.length);
    final payload = <String, dynamic>{
      'text': text,
      'session_id': sessionId,
      'images': const <String>[],
      'files': const <String>[],
      'audio_refs': const <String>[],
      'echo_user': true,
    };
    if (clientSessionId != null && clientSessionId.isNotEmpty) {
      payload['client_session_id'] = clientSessionId;
    }
    debugPrint('[Agent SSE] request payload: $payload');
    final lineStream = await _apiClient.streamPostLines(
      '/api/v1/message/agent/stream',
      data: payload,
    );
    return lineStream
        .map((line) {
          logger.logRawLine(line);
          return line;
        })
        .map(AgentStreamEvent.fromSseLine)
        .where((event) {
          if (event == null) return false;
          logger.logEvent(event);
          return true;
        })
        .cast<AgentStreamEvent>()
        .transform(
          StreamTransformer<AgentStreamEvent, AgentStreamEvent>.fromHandlers(
            handleDone: (sink) {
              logger.logStreamDone();
              sink.close();
            },
            handleError: (error, stackTrace, sink) {
              logger.logStreamError(error);
              sink.addError(error, stackTrace);
            },
          ),
        );
  }
}
