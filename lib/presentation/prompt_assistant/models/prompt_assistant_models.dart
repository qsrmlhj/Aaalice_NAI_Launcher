import 'dart:convert';

enum AssistantTaskType { llm, translate, reverse, characterReplace }

extension AssistantTaskTypeLabel on AssistantTaskType {
  String get label {
    switch (this) {
      case AssistantTaskType.llm:
        return '优化';
      case AssistantTaskType.translate:
        return '翻译';
      case AssistantTaskType.reverse:
        return '反推';
      case AssistantTaskType.characterReplace:
        return '角色替换';
    }
  }
}

enum ProviderType { pollinations, openaiCompatible, ollama }

class ProviderConfig {
  final String id;
  final String name;
  final ProviderType type;
  final String baseUrl;
  final bool enabled;
  final bool advancedParams;

  const ProviderConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.enabled = true,
    this.advancedParams = true,
  });

  ProviderConfig copyWith({
    String? id,
    String? name,
    ProviderType? type,
    String? baseUrl,
    bool? enabled,
    bool? advancedParams,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      advancedParams: advancedParams ?? this.advancedParams,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'baseUrl': baseUrl,
        'enabled': enabled,
        'advancedParams': advancedParams,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ProviderType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ProviderType.openaiCompatible,
      ),
      baseUrl: json['baseUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      advancedParams: json['advancedParams'] as bool? ?? true,
    );
  }
}

class ModelConfig {
  final String providerId;
  final String name;
  final String displayName;
  final AssistantTaskType forTask;
  final double temperature;
  final double topP;
  final int maxTokens;
  final bool isDefault;

  const ModelConfig({
    required this.providerId,
    required this.name,
    required this.displayName,
    required this.forTask,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 1024,
    this.isDefault = false,
  });

  ModelConfig copyWith({
    String? providerId,
    String? name,
    String? displayName,
    AssistantTaskType? forTask,
    double? temperature,
    double? topP,
    int? maxTokens,
    bool? isDefault,
  }) {
    return ModelConfig(
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      forTask: forTask ?? this.forTask,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'name': name,
        'displayName': displayName,
        'forTask': forTask.name,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'isDefault': isDefault,
      };

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      providerId: json['providerId'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String? ?? (json['name'] as String),
      forTask: AssistantTaskType.values.firstWhere(
        (t) => t.name == json['forTask'],
        orElse: () => AssistantTaskType.llm,
      ),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 1024,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class TaskRoutingConfig {
  final String llmProviderId;
  final String llmModel;
  final String translateProviderId;
  final String translateModel;
  final String reverseProviderId;
  final String reverseModel;
  final String characterReplaceProviderId;
  final String characterReplaceModel;

  const TaskRoutingConfig({
    required this.llmProviderId,
    required this.llmModel,
    required this.translateProviderId,
    required this.translateModel,
    required this.reverseProviderId,
    required this.reverseModel,
    required this.characterReplaceProviderId,
    required this.characterReplaceModel,
  });

  TaskRoutingConfig copyWith({
    String? llmProviderId,
    String? llmModel,
    String? translateProviderId,
    String? translateModel,
    String? reverseProviderId,
    String? reverseModel,
    String? characterReplaceProviderId,
    String? characterReplaceModel,
  }) {
    return TaskRoutingConfig(
      llmProviderId: llmProviderId ?? this.llmProviderId,
      llmModel: llmModel ?? this.llmModel,
      translateProviderId: translateProviderId ?? this.translateProviderId,
      translateModel: translateModel ?? this.translateModel,
      reverseProviderId: reverseProviderId ?? this.reverseProviderId,
      reverseModel: reverseModel ?? this.reverseModel,
      characterReplaceProviderId:
          characterReplaceProviderId ?? this.characterReplaceProviderId,
      characterReplaceModel:
          characterReplaceModel ?? this.characterReplaceModel,
    );
  }

  String providerIdFor(AssistantTaskType taskType) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return llmProviderId;
      case AssistantTaskType.translate:
        return translateProviderId;
      case AssistantTaskType.reverse:
        return reverseProviderId;
      case AssistantTaskType.characterReplace:
        return characterReplaceProviderId;
    }
  }

  String modelFor(AssistantTaskType taskType) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return llmModel;
      case AssistantTaskType.translate:
        return translateModel;
      case AssistantTaskType.reverse:
        return reverseModel;
      case AssistantTaskType.characterReplace:
        return characterReplaceModel;
    }
  }

  TaskRoutingConfig copyWithTask({
    required AssistantTaskType taskType,
    required String providerId,
    required String model,
  }) {
    switch (taskType) {
      case AssistantTaskType.llm:
        return copyWith(llmProviderId: providerId, llmModel: model);
      case AssistantTaskType.translate:
        return copyWith(
          translateProviderId: providerId,
          translateModel: model,
        );
      case AssistantTaskType.reverse:
        return copyWith(reverseProviderId: providerId, reverseModel: model);
      case AssistantTaskType.characterReplace:
        return copyWith(
          characterReplaceProviderId: providerId,
          characterReplaceModel: model,
        );
    }
  }

  Map<String, dynamic> toJson() => {
        'llmProviderId': llmProviderId,
        'llmModel': llmModel,
        'translateProviderId': translateProviderId,
        'translateModel': translateModel,
        'reverseProviderId': reverseProviderId,
        'reverseModel': reverseModel,
        'characterReplaceProviderId': characterReplaceProviderId,
        'characterReplaceModel': characterReplaceModel,
      };

  factory TaskRoutingConfig.fromJson(Map<String, dynamic> json) {
    return TaskRoutingConfig(
      llmProviderId: json['llmProviderId'] as String? ?? 'pollinations',
      llmModel: json['llmModel'] as String? ?? 'openai-large',
      translateProviderId:
          json['translateProviderId'] as String? ?? 'pollinations',
      translateModel: json['translateModel'] as String? ?? 'openai-large',
      reverseProviderId: json['reverseProviderId'] as String? ??
          json['llmProviderId'] as String? ??
          'pollinations',
      reverseModel: json['reverseModel'] as String? ??
          json['llmModel'] as String? ??
          'openai-large',
      characterReplaceProviderId:
          json['characterReplaceProviderId'] as String? ??
              json['llmProviderId'] as String? ??
              'pollinations',
      characterReplaceModel: json['characterReplaceModel'] as String? ??
          json['llmModel'] as String? ??
          'openai-large',
    );
  }
}

class PromptRuleTemplate {
  final String id;
  final String name;
  final AssistantTaskType taskType;
  final String content;
  final bool enabled;
  final bool isDefault;
  final int order;

  const PromptRuleTemplate({
    required this.id,
    required this.name,
    required this.taskType,
    required this.content,
    this.enabled = true,
    this.isDefault = false,
    this.order = 0,
  });

  PromptRuleTemplate copyWith({
    String? id,
    String? name,
    AssistantTaskType? taskType,
    String? content,
    bool? enabled,
    bool? isDefault,
    int? order,
  }) {
    return PromptRuleTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      taskType: taskType ?? this.taskType,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'taskType': taskType.name,
        'content': content,
        'enabled': enabled,
        'isDefault': isDefault,
        'order': order,
      };

  factory PromptRuleTemplate.fromJson(Map<String, dynamic> json) {
    return PromptRuleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      taskType: AssistantTaskType.values.firstWhere(
        (t) => t.name == json['taskType'],
        orElse: () => AssistantTaskType.llm,
      ),
      content: json['content'] as String,
      enabled: json['enabled'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreamingChunk {
  final String delta;
  final bool done;

  const StreamingChunk({required this.delta, this.done = false});
}

class AssistantOperationResult {
  final bool success;
  final String content;
  final String? error;

  const AssistantOperationResult({
    required this.success,
    required this.content,
    this.error,
  });
}

class PromptAssistantConfigState {
  final bool enabled;
  final bool desktopOverlayEnabled;
  final bool streamOutput;
  final List<ProviderConfig> providers;
  final List<ModelConfig> models;
  final TaskRoutingConfig routing;
  final List<PromptRuleTemplate> rules;
  final Map<String, bool> providerHasApiKey;

  const PromptAssistantConfigState({
    required this.enabled,
    required this.desktopOverlayEnabled,
    required this.streamOutput,
    required this.providers,
    required this.models,
    required this.routing,
    required this.rules,
    required this.providerHasApiKey,
  });

  factory PromptAssistantConfigState.defaults() {
    return const PromptAssistantConfigState(
      enabled: true,
      desktopOverlayEnabled: true,
      streamOutput: true,
      providers: [
        ProviderConfig(
          id: 'pollinations',
          name: 'pollinations.ai',
          type: ProviderType.pollinations,
          baseUrl: 'https://gen.pollinations.ai',
          enabled: true,
        ),
        ProviderConfig(
          id: 'openai_custom',
          name: 'OpenAI Compatible',
          type: ProviderType.openaiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          enabled: false,
        ),
        ProviderConfig(
          id: 'ollama',
          name: 'Ollama',
          type: ProviderType.ollama,
          baseUrl: 'http://127.0.0.1:11434/v1',
          enabled: false,
        ),
      ],
      models: [
        ModelConfig(
          providerId: 'pollinations',
          name: 'openai-large',
          displayName: 'openai-large',
          forTask: AssistantTaskType.llm,
          isDefault: true,
        ),
        ModelConfig(
          providerId: 'pollinations',
          name: 'openai-large',
          displayName: 'openai-large',
          forTask: AssistantTaskType.translate,
          isDefault: true,
        ),
        ModelConfig(
          providerId: 'pollinations',
          name: 'openai-large',
          displayName: 'openai-large',
          forTask: AssistantTaskType.reverse,
          isDefault: true,
        ),
        ModelConfig(
          providerId: 'pollinations',
          name: 'openai-large',
          displayName: 'openai-large',
          forTask: AssistantTaskType.characterReplace,
          isDefault: true,
        ),
      ],
      routing: TaskRoutingConfig(
        llmProviderId: 'pollinations',
        llmModel: 'openai-large',
        translateProviderId: 'pollinations',
        translateModel: 'openai-large',
        reverseProviderId: 'pollinations',
        reverseModel: 'openai-large',
        characterReplaceProviderId: 'pollinations',
        characterReplaceModel: 'openai-large',
      ),
      rules: [
        PromptRuleTemplate(
          id: 'opt_default',
          name: '默认优化规则',
          taskType: AssistantTaskType.llm,
          content: '你是提示词优化助手。保留用户核心意图，补充可执行细节，输出单行逗号分隔提示词。',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'translate_default',
          name: '默认翻译规则',
          taskType: AssistantTaskType.translate,
          content: '你是翻译助手。识别原文语言，自动在中英间互译，仅返回译文，不要解释。',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'reverse_default',
          name: '默认反推规则',
          taskType: AssistantTaskType.reverse,
          content:
              '你是图像反推助手。根据图片和可选 tagger 结果，输出适合 NovelAI 的英文逗号分隔提示词。保留主体、角色、画风、服装、动作、构图、光影和背景，不要解释。',
          isDefault: true,
        ),
        PromptRuleTemplate(
          id: 'character_replace_default',
          name: '默认角色替换规则',
          taskType: AssistantTaskType.characterReplace,
          content:
              '你是角色替换助手。将输入提示词中的原角色身份、发型、服装、外观替换为指定角色；保留动作、构图、背景、画风、镜头和质量词。仅输出替换后的单行提示词。',
          isDefault: true,
        ),
      ],
      providerHasApiKey: {},
    );
  }

  PromptAssistantConfigState copyWith({
    bool? enabled,
    bool? desktopOverlayEnabled,
    bool? streamOutput,
    List<ProviderConfig>? providers,
    List<ModelConfig>? models,
    TaskRoutingConfig? routing,
    List<PromptRuleTemplate>? rules,
    Map<String, bool>? providerHasApiKey,
  }) {
    return PromptAssistantConfigState(
      enabled: enabled ?? this.enabled,
      desktopOverlayEnabled:
          desktopOverlayEnabled ?? this.desktopOverlayEnabled,
      streamOutput: streamOutput ?? this.streamOutput,
      providers: providers ?? this.providers,
      models: models ?? this.models,
      routing: routing ?? this.routing,
      rules: rules ?? this.rules,
      providerHasApiKey: providerHasApiKey ?? this.providerHasApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'desktopOverlayEnabled': desktopOverlayEnabled,
        'streamOutput': streamOutput,
        'providers': providers.map((e) => e.toJson()).toList(),
        'models': models.map((e) => e.toJson()).toList(),
        'routing': routing.toJson(),
        'rules': rules.map((e) => e.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory PromptAssistantConfigState.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final defaults = PromptAssistantConfigState.defaults();

    final providersRaw = json['providers'];
    final providers = providersRaw is List && providersRaw.isNotEmpty
        ? providersRaw
            .map((e) => ProviderConfig.fromJson(e as Map<String, dynamic>))
            .toList()
        : defaults.providers;

    final modelsRaw = json['models'];
    final decodedModels = modelsRaw is List && modelsRaw.isNotEmpty
        ? modelsRaw
            .map((e) => ModelConfig.fromJson(e as Map<String, dynamic>))
            .toList()
        : defaults.models;
    final models = _mergeDefaultModels(decodedModels, defaults.models);

    var routing = TaskRoutingConfig.fromJson(
      (json['routing'] as Map?)?.cast<String, dynamic>() ??
          defaults.routing.toJson(),
    );
    if (!providers.any((p) => p.id == routing.llmProviderId)) {
      routing = routing.copyWith(
        llmProviderId: defaults.routing.llmProviderId,
        llmModel: defaults.routing.llmModel,
      );
    }
    if (!providers.any((p) => p.id == routing.translateProviderId)) {
      routing = routing.copyWith(
        translateProviderId: defaults.routing.translateProviderId,
        translateModel: defaults.routing.translateModel,
      );
    }
    if (!providers.any((p) => p.id == routing.reverseProviderId)) {
      routing = routing.copyWith(
        reverseProviderId: defaults.routing.reverseProviderId,
        reverseModel: defaults.routing.reverseModel,
      );
    }
    if (!providers.any((p) => p.id == routing.characterReplaceProviderId)) {
      routing = routing.copyWith(
        characterReplaceProviderId: defaults.routing.characterReplaceProviderId,
        characterReplaceModel: defaults.routing.characterReplaceModel,
      );
    }

    final rulesRaw = json['rules'];
    final decodedRules = rulesRaw is List && rulesRaw.isNotEmpty
        ? rulesRaw
            .map((e) => PromptRuleTemplate.fromJson(e as Map<String, dynamic>))
            .toList()
        : defaults.rules;
    final rules = _mergeDefaultRules(decodedRules, defaults.rules);

    return PromptAssistantConfigState(
      enabled: json['enabled'] as bool? ?? true,
      desktopOverlayEnabled: json['desktopOverlayEnabled'] as bool? ?? true,
      streamOutput: json['streamOutput'] as bool? ?? true,
      providers: providers,
      models: models,
      routing: routing,
      rules: rules,
      providerHasApiKey: const {},
    );
  }

  static List<ModelConfig> _mergeDefaultModels(
    List<ModelConfig> models,
    List<ModelConfig> defaults,
  ) {
    final result = [...models];
    for (final fallback in defaults) {
      final exists = result.any(
        (m) =>
            m.providerId == fallback.providerId &&
            m.name == fallback.name &&
            m.forTask == fallback.forTask,
      );
      if (!exists) {
        result.add(fallback);
      }
    }
    return result;
  }

  static List<PromptRuleTemplate> _mergeDefaultRules(
    List<PromptRuleTemplate> rules,
    List<PromptRuleTemplate> defaults,
  ) {
    final result = [...rules];
    for (final fallback in defaults) {
      final index = result.indexWhere((r) => r.id == fallback.id);
      if (index >= 0) {
        result[index] = result[index].copyWith(isDefault: true);
      } else {
        result.add(fallback);
      }
    }
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }
}
