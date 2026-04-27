import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../data/services/local_onnx_model_service.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/reverse_prompt_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/themed_divider.dart';

class ReversePromptPanel extends ConsumerStatefulWidget {
  const ReversePromptPanel({super.key});

  @override
  ConsumerState<ReversePromptPanel> createState() => _ReversePromptPanelState();
}

class _ReversePromptPanelState extends ConsumerState<ReversePromptPanel> {
  bool _isExpanded = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(reversePromptProvider);
    final hasImages = state.images.isNotEmpty;
    final showBackground = hasImages && !_isExpanded;

    return CollapsibleImagePanel(
      title: '反推',
      icon: Icons.manage_search_rounded,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasImages || state.finalPrompt.isNotEmpty,
      backgroundImage: showBackground
          ? DecodedMemoryImage(
              bytes: state.images.first.bytes,
              fit: BoxFit.cover,
              decodeScale: 0.75,
            )
          : null,
      badge: _buildBadge(context, state, showBackground),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            _buildDropArea(theme, state),
            if (hasImages) ...[
              const SizedBox(height: 10),
              _buildImageStrip(state),
            ],
            const SizedBox(height: 12),
            _buildChainToggles(state),
            if (state.useOnnxTagger) ...[
              const SizedBox(height: 8),
              _buildTaggerControls(state),
            ],
            if (state.useCharacterReplace) ...[
              const SizedBox(height: 8),
              _buildCharacterSelector(state),
            ],
            const SizedBox(height: 12),
            _buildActions(state),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (state.taggerPrompt.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PromptOutputBlock(
                title: 'ONNX tagger',
                text: state.taggerPrompt,
              ),
            ],
            if (state.llmPrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromptOutputBlock(title: 'LLM 反推', text: state.llmPrompt),
            ],
            if (state.finalPrompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromptOutputBlock(title: '最终结果', text: state.finalPrompt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    ReversePromptState state,
    bool showBackground,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: showBackground
            ? Colors.white.withValues(alpha: 0.2)
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.images.isEmpty ? '待添加' : '${state.images.length} 张',
        style: theme.textTheme.labelSmall?.copyWith(
          color: showBackground
              ? Colors.white
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildDropArea(ThemeData theme, ReversePromptState state) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (_) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDragging = false);
        unawaited(_handleDrop(event));
      },
      child: OutlinedButton.icon(
        onPressed: state.isProcessing ? null : _pickImages,
        icon: Icon(
          _isDragging ? Icons.file_download_rounded : Icons.add_photo_alternate,
          size: 18,
        ),
        label: Text(_isDragging ? '松开后添加到反推' : '增加图片 / 拖入图片'),
      ),
    );
  }

  Widget _buildImageStrip(ReversePromptState state) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = state.images[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: DecodedMemoryImage(
                    bytes: image.bytes,
                    fit: BoxFit.cover,
                    decodeScale: 0.75,
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => ref
                      .read(reversePromptProvider.notifier)
                      .removeImage(image.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChainToggles(ReversePromptState state) {
    final notifier = ref.read(reversePromptProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        FilterChip(
          label: const Text('ONNX tagger'),
          selected: state.useOnnxTagger,
          onSelected: state.isProcessing ? null : notifier.setUseOnnxTagger,
        ),
        FilterChip(
          label: const Text('LLM 反推'),
          selected: state.useLlmReverse,
          onSelected: state.isProcessing ? null : notifier.setUseLlmReverse,
        ),
        FilterChip(
          label: const Text('角色替换'),
          selected: state.useCharacterReplace,
          onSelected:
              state.isProcessing ? null : notifier.setUseCharacterReplace,
        ),
      ],
    );
  }

  Widget _buildTaggerControls(ReversePromptState state) {
    return FutureBuilder<List<LocalOnnxModelDescriptor>>(
      future: ref.read(localOnnxModelServiceProvider).scanTaggerModels(),
      builder: (context, snapshot) {
        final models = snapshot.data ?? const <LocalOnnxModelDescriptor>[];
        final selected =
            models.any((m) => m.path == state.selectedTaggerModelPath)
                ? state.selectedTaggerModelPath
                : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              items: models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.path,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: state.isProcessing
                  ? null
                  : ref
                      .read(reversePromptProvider.notifier)
                      .setSelectedTaggerModelPath,
              decoration: const InputDecoration(
                labelText: '本地 tagger 模型',
                hintText: '请在设置中配置模型文件夹',
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('阈值 ${state.taggerThreshold.toStringAsFixed(2)}'),
                Expanded(
                  child: Slider(
                    value: state.taggerThreshold,
                    min: 0.05,
                    max: 0.95,
                    divisions: 18,
                    onChanged: state.isProcessing
                        ? null
                        : ref
                            .read(reversePromptProvider.notifier)
                            .setTaggerThreshold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCharacterSelector(ReversePromptState state) {
    final characters = ref
        .watch(characterPromptNotifierProvider)
        .characters
        .where((c) => c.enabled && c.prompt.trim().isNotEmpty)
        .toList();
    final selected = characters.any((c) => c.id == state.selectedCharacterId)
        ? state.selectedCharacterId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      items: characters
          .map(
            (character) => DropdownMenuItem(
              value: character.id,
              child: Text(character.name),
            ),
          )
          .toList(),
      onChanged: state.isProcessing
          ? null
          : ref.read(reversePromptProvider.notifier).setSelectedCharacterId,
      decoration: const InputDecoration(
        labelText: '替换目标角色',
        hintText: '从提示词角色/词库中选择',
        isDense: true,
      ),
    );
  }

  Widget _buildActions(ReversePromptState state) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: state.isProcessing || !state.canRun
                ? null
                : ref.read(reversePromptProvider.notifier).runChain,
            icon: state.isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(state.processingLabel ?? '开始反推'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.finalPrompt.trim().isEmpty
              ? null
              : () {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updatePrompt(state.finalPrompt.trim());
                  AppToast.success(context, '已发送到提示词');
                },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('发送到提示词'),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) {
      return;
    }
    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      final bytes = await File(path).readAsBytes();
      await ref
          .read(reversePromptProvider.notifier)
          .addImage(bytes, name: file.name);
    }
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) {
        continue;
      }
      final file = await _readDroppedImage(reader);
      if (file != null) {
        await ref
            .read(reversePromptProvider.notifier)
            .addImage(file.$2, name: file.$1);
      }
    }
  }

  Future<(String, Uint8List)?> _readDroppedImage(DataReader reader) async {
    if (reader.canProvide(Formats.fileUri)) {
      final uri = await _getFileUri(reader);
      if (uri == null) {
        return null;
      }
      final file = File(uri.toFilePath());
      if (!await file.exists()) {
        return null;
      }
      return (file.uri.pathSegments.last, await file.readAsBytes());
    }

    final format = reader.canProvide(Formats.png)
        ? Formats.png
        : reader.canProvide(Formats.jpeg)
            ? Formats.jpeg
            : null;
    if (format == null) {
      return null;
    }
    final dropped = await _getImageFile(reader, format);
    if (dropped == null) {
      return null;
    }
    final extension = format == Formats.png ? 'png' : 'jpg';
    return (
      dropped.fileName ?? 'dropped_image.$extension',
      await dropped.readAll()
    );
  }

  Future<Uri?> _getFileUri(DataReader reader) {
    final completer = Completer<Uri?>();
    final progress = reader.getValue(
      Formats.fileUri,
      (uri) {
        if (!completer.isCompleted) completer.complete(uri);
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) {
      return Future.value();
    }
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  Future<DataReaderFile?> _getImageFile(
    DataReader reader,
    FileFormat format,
  ) {
    final completer = Completer<DataReaderFile?>();
    final progress = reader.getFile(
      format,
      (file) {
        if (!completer.isCompleted) completer.complete(file);
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) {
      return Future.value();
    }
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }
}

class _PromptOutputBlock extends StatelessWidget {
  const _PromptOutputBlock({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
