import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../widgets/settings_card.dart';

class PromptAssistantSettingsSection extends ConsumerWidget {
  const PromptAssistantSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptAssistantConfigProvider);
    final notifier = ref.read(promptAssistantConfigProvider.notifier);

    return SettingsCard(
      title: 'Prompt Assistant',
      icon: Icons.auto_awesome,
      child: Column(
        children: [
          SwitchListTile(
            value: state.enabled,
            title: const Text('启用提示词助手'),
            subtitle: const Text('输入框右下角助手开关'),
            onChanged: notifier.setEnabled,
          ),
          SwitchListTile(
            value: state.desktopOverlayEnabled,
            title: const Text('桌面浮层交互'),
            subtitle: const Text('启用 hover / 右键 / 快捷键行为'),
            onChanged: notifier.setDesktopOverlayEnabled,
          ),
          SwitchListTile(
            value: state.streamOutput,
            title: const Text('流式输出'),
            subtitle: const Text('优化和翻译时逐段覆盖输入框'),
            onChanged: notifier.setStreamOutput,
          ),
          const Divider(),
          _buildRouting(context, state, notifier),
          const Divider(),
          _buildProviders(context, ref, state, notifier),
          const Divider(),
          _buildRules(context, state, notifier),
        ],
      ),
    );
  }

  Widget _buildRouting(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final providerItems = state.providers
        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
        .toList();

    final llmModels = state.models
        .where(
          (m) =>
              m.providerId == state.routing.llmProviderId &&
              m.forTask == AssistantTaskType.llm,
        )
        .toList();
    final translateModels = state.models
        .where(
          (m) =>
              m.providerId == state.routing.translateProviderId &&
              m.forTask == AssistantTaskType.translate,
        )
        .toList();
    final llmModelItems = llmModels
        .map(
          (m) => DropdownMenuItem(
            value: m.name,
            child: Text(m.displayName),
          ),
        )
        .toList();
    final translateModelItems = translateModels
        .map(
          (m) => DropdownMenuItem(
            value: m.name,
            child: Text(m.displayName),
          ),
        )
        .toList();
    final llmModelValue = llmModels.any((m) => m.name == state.routing.llmModel)
        ? state.routing.llmModel
        : null;
    final translateModelValue = translateModels.any(
      (m) => m.name == state.routing.translateModel,
    )
        ? state.routing.translateModel
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4),
          title: Text('任务路由'),
          subtitle: Text('优化与翻译可绑定不同服务商和模型'),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth > 860;
            final optimizeCard = _buildTaskRouteCard(
              context: context,
              title: '优化',
              providerValue: state.routing.llmProviderId,
              providerItems: providerItems,
              onProviderChanged: (value) {
                if (value == null) return;
                final firstModel = state.models.firstWhere(
                  (m) =>
                      m.providerId == value &&
                      m.forTask == AssistantTaskType.llm,
                  orElse: () => ModelConfig(
                    providerId: value,
                    name: 'default-model',
                    displayName: 'default-model',
                    forTask: AssistantTaskType.llm,
                  ),
                );
                notifier.setRouting(
                  state.routing.copyWith(
                    llmProviderId: value,
                    llmModel: firstModel.name,
                  ),
                );
              },
              modelValue: llmModelValue,
              modelItems: llmModelItems,
              onModelChanged: llmModelItems.isEmpty
                  ? null
                  : (value) {
                      if (value == null) return;
                      notifier
                          .setRouting(state.routing.copyWith(llmModel: value));
                    },
              onParamsPressed: () => _showModelParamDialog(
                context,
                notifier,
                state,
                AssistantTaskType.llm,
              ),
            );
            final translateCard = _buildTaskRouteCard(
              context: context,
              title: '翻译',
              providerValue: state.routing.translateProviderId,
              providerItems: providerItems,
              onProviderChanged: (value) {
                if (value == null) return;
                final firstModel = state.models.firstWhere(
                  (m) =>
                      m.providerId == value &&
                      m.forTask == AssistantTaskType.translate,
                  orElse: () => ModelConfig(
                    providerId: value,
                    name: 'default-model',
                    displayName: 'default-model',
                    forTask: AssistantTaskType.translate,
                  ),
                );
                notifier.setRouting(
                  state.routing.copyWith(
                    translateProviderId: value,
                    translateModel: firstModel.name,
                  ),
                );
              },
              modelValue: translateModelValue,
              modelItems: translateModelItems,
              onModelChanged: translateModelItems.isEmpty
                  ? null
                  : (value) {
                      if (value == null) return;
                      notifier.setRouting(
                        state.routing.copyWith(translateModel: value),
                      );
                    },
              onParamsPressed: () => _showModelParamDialog(
                context,
                notifier,
                state,
                AssistantTaskType.translate,
              ),
            );

            if (twoCols) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: optimizeCard),
                  const SizedBox(width: 12),
                  Expanded(child: translateCard),
                ],
              );
            }

            return Column(
              children: [
                optimizeCard,
                const SizedBox(height: 10),
                translateCard,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskRouteCard({
    required BuildContext context,
    required String title,
    required String providerValue,
    required List<DropdownMenuItem<String>> providerItems,
    required ValueChanged<String?> onProviderChanged,
    required String? modelValue,
    required List<DropdownMenuItem<String>> modelItems,
    required ValueChanged<String?>? onModelChanged,
    required VoidCallback onParamsPressed,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title任务',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onParamsPressed,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text('参数'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: providerValue,
              isExpanded: true,
              items: providerItems,
              onChanged: onProviderChanged,
              decoration: const InputDecoration(
                labelText: '服务商',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: modelValue,
              isExpanded: true,
              hint: const Text('暂无模型，请先拉取'),
              items: modelItems,
              onChanged: onModelChanged,
              decoration: const InputDecoration(
                labelText: '模型',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviders(
    BuildContext context,
    WidgetRef ref,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    return Column(
      children: [
        ListTile(
          title: const Text('服务商管理'),
          subtitle: const Text('支持 pollinations / OpenAI-compatible / Ollama'),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProviderDialog(context, notifier, state),
          ),
        ),
        ...state.providers.map((provider) {
          final hasApiKey = state.providerHasApiKey[provider.id] ?? false;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Switch(
                  value: provider.enabled,
                  onChanged: (value) {
                    notifier.upsertProvider(provider.copyWith(enabled: value));
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${provider.type.name}  ${provider.baseUrl}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasApiKey ? 'API Key: 已配置' : 'API Key: 未配置',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 240, maxWidth: 360),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showConnectionDialog(
                            context,
                            notifier,
                            provider: provider,
                          ),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('连接配置'),
                        ),
                        Icon(
                          hasApiKey ? Icons.key : Icons.key_off,
                          size: 18,
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_for_offline_outlined),
                          tooltip: '拉取模型列表',
                          onPressed: () => _pullProviderModels(
                            context,
                            ref,
                            notifier,
                            provider.id,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: '编辑服务商',
                          onPressed: () => _showProviderDialog(
                            context,
                            notifier,
                            state,
                            provider: provider,
                          ),
                        ),
                        if (provider.id != 'pollinations')
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除服务商',
                            onPressed: () =>
                                notifier.deleteProvider(provider.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pullProviderModels(
    BuildContext context,
    WidgetRef ref,
    PromptAssistantConfigNotifier notifier,
    String providerId,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text('正在拉取模型列表...')),
    );

    try {
      final service = ref.read(promptAssistantServiceProvider);
      final modelNames = await service.fetchAvailableModels(providerId);
      if (modelNames.isEmpty) {
        throw StateError('服务返回空模型列表');
      }

      final latestState = ref.read(promptAssistantConfigProvider);
      for (final task in AssistantTaskType.values) {
        for (final name in modelNames) {
          final exists = latestState.models.any(
            (m) =>
                m.providerId == providerId &&
                m.forTask == task &&
                m.name == name,
          );
          if (!exists) {
            await notifier.upsertModel(
              ModelConfig(
                providerId: providerId,
                name: name,
                displayName: name,
                forTask: task,
              ),
            );
          }
        }
      }

      final updated = ref.read(promptAssistantConfigProvider);
      final modelSet = modelNames.toSet();
      var routing = updated.routing;
      var changed = false;

      if (routing.llmProviderId == providerId &&
          !modelSet.contains(routing.llmModel)) {
        routing = routing.copyWith(llmModel: modelNames.first);
        changed = true;
      }
      if (routing.translateProviderId == providerId &&
          !modelSet.contains(routing.translateModel)) {
        routing = routing.copyWith(translateModel: modelNames.first);
        changed = true;
      }

      if (changed) {
        await notifier.setRouting(routing);
      }

      messenger?.showSnackBar(
        SnackBar(content: Text('已同步 ${modelNames.length} 个模型')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('拉取模型失败: $e')),
      );
    }
  }

  Widget _buildRules(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final rules = [...state.rules]..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      children: [
        const ListTile(
          title: Text('规则模板'),
          subtitle: Text('系统提示词按“规则 + 用户输入 + 任务参数”组装'),
        ),
        ...rules.map(
          (rule) => ListTile(
            title: Text(rule.name),
            subtitle: Text(
              rule.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Switch(
              value: rule.enabled,
              onChanged: (value) {
                notifier.upsertRule(rule.copyWith(enabled: value));
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showRuleDialog(context, notifier, rule: rule),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showRuleDialog(context, notifier),
            icon: const Icon(Icons.add),
            label: const Text('新增规则'),
          ),
        ),
      ],
    );
  }

  Future<void> _showProviderDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier,
    PromptAssistantConfigState state, {
    ProviderConfig? provider,
  }) async {
    final idController = TextEditingController(text: provider?.id ?? '');
    final nameController = TextEditingController(text: provider?.name ?? '');
    final baseController = TextEditingController(text: provider?.baseUrl ?? '');
    final keyController = TextEditingController();
    var type = provider?.type ?? ProviderType.openaiCompatible;
    var advancedParams = provider?.advancedParams ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(provider == null ? '新增服务商' : '编辑服务商'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'ID'),
                      enabled: provider == null,
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    DropdownButtonFormField<ProviderType>(
                      value: type,
                      items: ProviderType.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => type = value);
                      },
                      decoration: const InputDecoration(labelText: '类型'),
                    ),
                    TextField(
                      controller: baseController,
                      decoration: const InputDecoration(labelText: 'Base URL'),
                    ),
                    TextField(
                      controller: keyController,
                      decoration:
                          const InputDecoration(labelText: 'API Key (留空不改)'),
                      obscureText: true,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: advancedParams,
                      onChanged: (value) =>
                          setState(() => advancedParams = value),
                      title: const Text('启用高级参数'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final resolvedId = (provider?.id ?? idController.text.trim());
    final next = ProviderConfig(
      id: resolvedId,
      name: nameController.text.trim().isEmpty
          ? resolvedId
          : nameController.text.trim(),
      type: type,
      baseUrl: baseController.text.trim(),
      enabled: provider?.enabled ?? true,
      advancedParams: advancedParams,
    );

    await notifier.upsertProvider(next);

    if (keyController.text.trim().isNotEmpty) {
      await notifier.setProviderApiKey(resolvedId, keyController.text);
    }

    final hasLlmModel = state.models.any(
      (m) => m.providerId == resolvedId && m.forTask == AssistantTaskType.llm,
    );
    final hasTranslateModel = state.models.any(
      (m) =>
          m.providerId == resolvedId &&
          m.forTask == AssistantTaskType.translate,
    );

    if (!hasLlmModel) {
      await notifier.upsertModel(
        ModelConfig(
          providerId: resolvedId,
          name: 'default-model',
          displayName: 'default-model',
          forTask: AssistantTaskType.llm,
          isDefault: true,
        ),
      );
    }
    if (!hasTranslateModel) {
      await notifier.upsertModel(
        ModelConfig(
          providerId: resolvedId,
          name: 'default-model',
          displayName: 'default-model',
          forTask: AssistantTaskType.translate,
          isDefault: true,
        ),
      );
    }
  }

  Future<void> _showConnectionDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier, {
    required ProviderConfig provider,
  }) async {
    final baseController = TextEditingController(text: provider.baseUrl);
    final keyController = TextEditingController();
    var clearApiKey = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${provider.name} 连接配置'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baseController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: '例如: https://api.openai.com/v1',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key (留空不改)',
                      ),
                      obscureText: true,
                    ),
                    CheckboxListTile(
                      value: clearApiKey,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('清空当前 API Key'),
                      onChanged: (value) {
                        setState(() => clearApiKey = value ?? false);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await notifier.upsertProvider(
      provider.copyWith(baseUrl: baseController.text.trim()),
    );

    if (clearApiKey) {
      await notifier.setProviderApiKey(provider.id, '');
      return;
    }

    if (keyController.text.trim().isNotEmpty) {
      await notifier.setProviderApiKey(provider.id, keyController.text);
    }
  }

  Future<void> _showRuleDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier, {
    PromptRuleTemplate? rule,
  }) async {
    final nameController = TextEditingController(text: rule?.name ?? '');
    final contentController = TextEditingController(text: rule?.content ?? '');
    var taskType = rule?.taskType ?? AssistantTaskType.llm;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(rule == null ? '新增规则' : '编辑规则'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    DropdownButtonFormField<AssistantTaskType>(
                      value: taskType,
                      items: AssistantTaskType.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => taskType = value);
                      },
                      decoration: const InputDecoration(labelText: '任务类型'),
                    ),
                    TextField(
                      controller: contentController,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: '规则内容'),
                    ),
                  ],
                ),
              ),
              actions: [
                if (rule != null)
                  TextButton(
                    onPressed: () async {
                      await notifier.removeRule(rule.id);
                      if (context.mounted) Navigator.pop(context, false);
                    },
                    child: const Text('删除'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final next = PromptRuleTemplate(
      id: rule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim().isEmpty
          ? '新规则'
          : nameController.text.trim(),
      taskType: taskType,
      content: contentController.text.trim(),
      enabled: rule?.enabled ?? true,
      isDefault: rule?.isDefault ?? false,
      order: rule?.order ?? 100,
    );

    await notifier.upsertRule(next);
  }

  Future<void> _showModelParamDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier,
    PromptAssistantConfigState state,
    AssistantTaskType taskType,
  ) async {
    final providerId = taskType == AssistantTaskType.llm
        ? state.routing.llmProviderId
        : state.routing.translateProviderId;
    final modelName = taskType == AssistantTaskType.llm
        ? state.routing.llmModel
        : state.routing.translateModel;

    final model = state.models.firstWhere(
      (m) =>
          m.providerId == providerId &&
          m.name == modelName &&
          m.forTask == taskType,
      orElse: () => ModelConfig(
        providerId: providerId,
        name: modelName,
        displayName: modelName,
        forTask: taskType,
        isDefault: true,
      ),
    );

    final nameController = TextEditingController(text: model.name);
    final displayController = TextEditingController(text: model.displayName);
    final temperatureController =
        TextEditingController(text: model.temperature.toString());
    final topPController = TextEditingController(text: model.topP.toString());
    final maxTokensController =
        TextEditingController(text: model.maxTokens.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(taskType == AssistantTaskType.llm ? '优化模型参数' : '翻译模型参数'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '模型名'),
                ),
                TextField(
                  controller: displayController,
                  decoration: const InputDecoration(labelText: '显示名'),
                ),
                TextField(
                  controller: temperatureController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'temperature'),
                ),
                TextField(
                  controller: topPController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'top_p'),
                ),
                TextField(
                  controller: maxTokensController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'max_tokens'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final nextModel = model.copyWith(
      name: nameController.text.trim().isEmpty
          ? model.name
          : nameController.text.trim(),
      displayName: displayController.text.trim().isEmpty
          ? model.displayName
          : displayController.text.trim(),
      temperature: double.tryParse(temperatureController.text.trim()) ??
          model.temperature,
      topP: double.tryParse(topPController.text.trim()) ?? model.topP,
      maxTokens:
          int.tryParse(maxTokensController.text.trim()) ?? model.maxTokens,
    );

    await notifier.upsertModel(nextModel);

    if (taskType == AssistantTaskType.llm) {
      await notifier.setRouting(
        state.routing.copyWith(llmModel: nextModel.name),
      );
    } else {
      await notifier.setRouting(
        state.routing.copyWith(translateModel: nextModel.name),
      );
    }
  }
}
