import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/prompt_assistant_models.dart';

class PromptAssistantApiClient {
  PromptAssistantApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  void cancelCurrentRequest({String? sessionId}) {
    if (sessionId == null || sessionId.isEmpty) {
      for (final token in _cancelTokens.values) {
        token.cancel('cancelled by user');
      }
      _cancelTokens.clear();
      return;
    }

    final token = _cancelTokens.remove(sessionId);
    token?.cancel('cancelled by user');
  }

  Future<List<String>> fetchModels({
    required ProviderConfig provider,
    required String? apiKey,
  }) async {
    if (provider.type == ProviderType.pollinations) {
      return const ['openai-large'];
    }

    final headers = <String, dynamic>{};
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final endpoints = <String>[
      _resolveModelsEndpoint(provider),
      if (provider.type == ProviderType.ollama)
        _resolveOllamaTagsEndpoint(provider),
    ];

    DioException? lastError;
    for (final endpoint in endpoints.toSet()) {
      try {
        final response = await _dio.get<dynamic>(
          endpoint,
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        final names = _extractModelNames(response.data);
        if (names.isNotEmpty) {
          return names;
        }
      } on DioException catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    return const [];
  }

  Stream<StreamingChunk> streamChat({
    required String sessionId,
    required ProviderConfig provider,
    required String model,
    required List<Map<String, String>> messages,
    required double temperature,
    required double topP,
    required int maxTokens,
    required bool advancedParams,
    required String? apiKey,
  }) async* {
    _cancelTokens.remove(sessionId)?.cancel('replaced by new request');
    final cancelToken = CancelToken();
    _cancelTokens[sessionId] = cancelToken;

    final endpoint = _resolveEndpoint(provider);
    final payload = <String, dynamic>{
      'model': model,
      'stream': true,
      'messages': messages,
    };

    if (advancedParams) {
      payload['temperature'] = temperature;
      payload['top_p'] = topP;
      payload['max_tokens'] = maxTokens;
    }

    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    try {
      Response<ResponseBody> response;
      try {
        response = await _dio.post<ResponseBody>(
          endpoint,
          data: payload,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 2),
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        // retry once with degraded payload
        if (e.response?.statusCode == 400) {
          final degradedPayload = {
            'model': model,
            'stream': true,
            'messages': messages,
          };
          response = await _dio.post<ResponseBody>(
            endpoint,
            data: degradedPayload,
            options: Options(
              responseType: ResponseType.stream,
              headers: headers,
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 2),
            ),
            cancelToken: cancelToken,
          );
        } else {
          rethrow;
        }
      }

      final stream = response.data?.stream;
      if (stream == null) {
        yield const StreamingChunk(delta: '', done: true);
        return;
      }

      final buffer = StringBuffer();

      await for (final bytes in stream) {
        final text = utf8.decode(bytes, allowMalformed: true);
        buffer.write(text);
        var content = buffer.toString();
        var breakIndex = content.indexOf('\n');
        while (breakIndex >= 0) {
          final line = content.substring(0, breakIndex).trim();
          content = content.substring(breakIndex + 1);
          if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data == '[DONE]') {
              yield const StreamingChunk(delta: '', done: true);
              return;
            }
            if (data.isNotEmpty) {
              final delta = _extractDelta(data);
              if (delta.isNotEmpty) {
                yield StreamingChunk(delta: delta);
              }
            }
          }
          breakIndex = content.indexOf('\n');
        }
        buffer
          ..clear()
          ..write(content);
      }

      yield const StreamingChunk(delta: '', done: true);
    } finally {
      if (identical(_cancelTokens[sessionId], cancelToken)) {
        _cancelTokens.remove(sessionId);
      }
    }
  }

  String _resolveEndpoint(ProviderConfig provider) {
    if (provider.type == ProviderType.pollinations) {
      return 'https://gen.pollinations.ai/v1/chat/completions';
    }

    final base = _normalizedBase(provider);
    if (base.endsWith('/chat/completions')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/chat/completions';
    }
    return '$base/v1/chat/completions';
  }

  String _extractDelta(String jsonLine) {
    try {
      final obj = jsonDecode(jsonLine) as Map<String, dynamic>;
      final choices = obj['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final delta = first['delta'];
          if (delta is Map<String, dynamic>) {
            return (delta['content'] as String?) ?? '';
          }
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            return (message['content'] as String?) ?? '';
          }
        }
      }
      final text = obj['text'];
      if (text is String) return text;
    } catch (_) {
      // ignore parse errors in incomplete frames
    }
    return '';
  }

  String _normalizedBase(ProviderConfig provider) {
    return provider.baseUrl.trim().replaceAll(RegExp(r"/+$"), "");
  }

  String _resolveModelsEndpoint(ProviderConfig provider) {
    final base = _normalizedBase(provider);
    if (base.endsWith('/v1')) {
      return '$base/models';
    }
    return '$base/v1/models';
  }

  String _resolveOllamaTagsEndpoint(ProviderConfig provider) {
    final base = _normalizedBase(provider);
    if (base.endsWith('/v1')) {
      return '${base.substring(0, base.length - 3)}/api/tags';
    }
    return '$base/api/tags';
  }

  List<String> _extractModelNames(dynamic raw) {
    final names = <String>[];

    void addName(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        names.add(value.trim());
      }
    }

    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            addName(item['id'] ?? item['name'] ?? item['model']);
          } else {
            addName(item);
          }
        }
      }
      final models = raw['models'];
      if (models is List) {
        for (final item in models) {
          if (item is Map<String, dynamic>) {
            addName(item['name'] ?? item['model'] ?? item['id']);
          } else {
            addName(item);
          }
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          addName(item['id'] ?? item['name'] ?? item['model']);
        } else {
          addName(item);
        }
      }
    }

    final dedup = <String>{};
    return names.where((name) => dedup.add(name)).toList();
  }
}
