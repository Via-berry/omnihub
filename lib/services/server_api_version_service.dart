import 'package:get/get.dart';
import 'package:moviepilot_mobile/services/api_client.dart';

class ServerApiVersionService extends GetxService {
  final _apiClient = Get.find<ApiClient>();
  final _cache = <String, bool>{};
  final _inFlight = <String, Future<bool>>{};
  int _generation = 0;

  Future<bool> isV3() {
    final baseUrl = _normalizeBaseUrl(_apiClient.baseUrl);
    if (baseUrl == null) return Future.value(false);
    final cached = _cache[baseUrl];
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[baseUrl];
    if (pending != null) return pending;

    final generation = _generation;
    final detection = _detect(baseUrl, generation);
    _inFlight[baseUrl] = detection;
    return detection;
  }

  Future<bool> _detect(String baseUrl, int generation) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/media/source',
        skipV3EnvelopeUnwrap: true,
      );
      final data = response.data;
      final hasSourceList =
          data is List ||
          (data is Map && data.containsKey('data') && data['data'] is List);
      final result = response.statusCode == 200 && hasSourceList;
      if (generation == _generation) {
        _cache[baseUrl] = result;
      }
      return result;
    } catch (_) {
      return false;
    } finally {
      if (generation == _generation) {
        _inFlight.remove(baseUrl);
      }
    }
  }

  void markV3(String? baseUrl, bool isV3) {
    final key = _normalizeBaseUrl(baseUrl ?? _apiClient.baseUrl);
    if (key == null) return;
    _cache[key] = isV3;
    _inFlight.remove(key);
  }

  void reset() {
    _generation++;
    _cache.clear();
    _inFlight.clear();
  }

  void invalidate(String? baseUrl) {
    final key = _normalizeBaseUrl(baseUrl ?? _apiClient.baseUrl);
    if (key == null) return;
    _generation++;
    _cache.remove(key);
    _inFlight.clear();
  }

  String? _normalizeBaseUrl(String? baseUrl) {
    final normalized = baseUrl?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
