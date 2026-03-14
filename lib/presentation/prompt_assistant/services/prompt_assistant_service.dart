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

  Stream<StreamingChunk> _runTask({
    required String sessionId,
    required AssistantTaskType taskType,
    required String userContent,
    required String userInstruction,
  }) async* {
    final config = _ref.read(promptAssistantConfigProvider);

    final routingProviderId = taskType == AssistantTaskType.llm
        ? config.routing.llmProviderId
        : config.routing.translateProviderId;
    final routingModel = taskType == AssistantTaskType.llm
        ? config.routing.llmModel
        : config.routing.translateModel;

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

    final messages = <Map<String, String>>[
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
}
