import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/prompt_assistant_models.dart';
import '../providers/prompt_assistant_config_provider.dart';
import 'prompt_assistant_api_client.dart';

final promptAssistantDioProvider = Provider<Dio>((ref) {
  // 使用独立 Dio，避免第三方服务的 401 触发全局登录态刷新/登出逻辑。
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
});

final promptAssistantServiceProvider = Provider<PromptAssistantService>((ref) {
  final dio = ref.watch(promptAssistantDioProvider);
  return PromptAssistantService(
    ref: ref,
    apiClient: PromptAssistantApiClient(dio: dio),
  );
});

class PromptAssistantService {
  PromptAssistantService({
    required Ref ref,
    required PromptAssistantApiClient apiClient,
  })  : _ref = ref,
        _apiClient = apiClient;

  final Ref _ref;
  final PromptAssistantApiClient _apiClient;

  Future<void> cancelCurrentTask({String? sessionId}) async {
    _apiClient.cancelCurrentRequest(sessionId: sessionId);
  }

  Future<List<String>> fetchAvailableModels(String providerId) async {
    final config = _ref.read(promptAssistantConfigProvider);
    final provider = config.providers.firstWhere(
      (p) => p.id == providerId,
      orElse: () => throw StateError('未找到服务商: $providerId'),
    );
    final apiKey = await _ref
        .read(promptAssistantConfigProvider.notifier)
        .getProviderApiKey(provider.id);
    return _apiClient.fetchModels(provider: provider, apiKey: apiKey);
  }

  Stream<StreamingChunk> optimizePrompt(
    String input, {
    required String sessionId,
  }) async* {
    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.llm,
      userContent: input,
      userInstruction: '请优化这段图像生成提示词，保留原意并增强细节，输出单行结果。',
    );
  }

  Stream<StreamingChunk> translatePrompt(
    String input, {
    required String sessionId,
    String? targetLanguage,
  }) async* {
    final instruction = targetLanguage == null || targetLanguage.isEmpty
        ? '请自动识别原文语言，在中文和英文之间互译，仅返回译文。'
        : '请将文本翻译为$targetLanguage，仅返回译文。';
    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.translate,
      userContent: input,
      userInstruction: instruction,
    );
  }

  Stream<StreamingChunk> reverseImagePrompt(
    Uint8List imageBytes, {
    required String sessionId,
    String? taggerPrompt,
  }) async* {
    final text = StringBuffer(
      '请反推这张图片，输出 NovelAI 可直接使用的英文逗号分隔提示词。',
    );
    final trimmedTags = taggerPrompt?.trim();
    if (trimmedTags != null && trimmedTags.isNotEmpty) {
      text
        ..write('\n\n本地 ONNX tagger 初步结果如下，请结合图片判断取舍：\n')
        ..write(trimmedTags);
    }

    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.reverse,
      userContent: [
        {'type': 'text', 'text': text.toString()},
        {
          'type': 'image_url',
          'image_url': {'url': _imageDataUri(imageBytes)},
        },
      ],
      userInstruction: '请严格输出单行英文提示词，不要 Markdown，不要解释。优先保留可见元素，避免编造不可见角色信息。',
    );
  }

  Stream<StreamingChunk> replaceCharacterPrompt(
    String input, {
    required String sessionId,
    required String characterName,
    required String characterPrompt,
  }) async* {
    yield* _runTask(
      sessionId: sessionId,
      taskType: AssistantTaskType.characterReplace,
      userContent:
          '目标角色名称：$characterName\n目标角色提示词：$characterPrompt\n\n待替换提示词：\n$input',
      userInstruction: '请只替换角色身份和角色外观相关部分，保留动作、构图、场景、画风、镜头、质量词和负面约束之外的上下文。',
    );
  }

  Stream<StreamingChunk> _runTask({
    required String sessionId,
    required AssistantTaskType taskType,
    required Object userContent,
    required String userInstruction,
  }) async* {
    final config = _ref.read(promptAssistantConfigProvider);

    final routingProviderId = config.routing.providerIdFor(taskType);
    final routingModel = config.routing.modelFor(taskType);

    final provider = config.providers.firstWhere(
      (p) => p.id == routingProviderId && p.enabled,
      orElse: () => config.providers.firstWhere(
        (p) => p.enabled,
        orElse: () => throw StateError('没有可用的已启用服务商'),
      ),
    );

    final model = config.models.firstWhere(
      (m) =>
          m.providerId == provider.id &&
          m.forTask == taskType &&
          m.name == routingModel,
      orElse: () => config.models.firstWhere(
        (m) => m.providerId == provider.id && m.forTask == taskType,
        orElse: () => ModelConfig(
          providerId: provider.id,
          name: routingModel,
          displayName: routingModel,
          forTask: taskType,
          isDefault: true,
        ),
      ),
    );

    final apiKey = await _ref
        .read(promptAssistantConfigProvider.notifier)
        .getProviderApiKey(provider.id);

    final activeRules = config.rules
        .where((r) => r.taskType == taskType && r.enabled)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final systemPrompt = [
      ...activeRules.map((e) => e.content.trim()).where((e) => e.isNotEmpty),
      userInstruction,
    ].join('\n\n');

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userContent},
    ];

    yield* _apiClient.streamChat(
      sessionId: sessionId,
      provider: provider,
      model: model.name,
      messages: messages,
      temperature: model.temperature,
      topP: model.topP,
      maxTokens: model.maxTokens,
      advancedParams: provider.advancedParams,
      apiKey: apiKey,
    );
  }

  String _imageDataUri(Uint8List imageBytes) {
    final mime = _detectImageMime(imageBytes);
    return 'data:$mime;base64,${base64Encode(imageBytes)}';
  }

  String _detectImageMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/png';
  }
}
