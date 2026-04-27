import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../../core/comfyui/comfyui_models.dart';
import '../../../../core/comfyui/workflow_template.dart';
import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/services/local_onnx_model_service.dart';
import '../../../../data/services/local_onnx_upscale_service.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../services/image_workflow_launcher.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../widgets/common/image_picker_card/image_picker_card.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/image_editor/painters/focused_overlay_painter.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import 'img2img_preview_cache.dart';
import 'comfyui_workflow_dialog.dart';

/// Img2Img 面板组件
class Img2ImgPanel extends ConsumerStatefulWidget {
  const Img2ImgPanel({super.key});

  @override
  ConsumerState<Img2ImgPanel> createState() => _Img2ImgPanelState();
}

class _Img2ImgPanelState extends ConsumerState<Img2ImgPanel> {
  bool _naiUpscaling = false;
  bool _localOnnxUpscaling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(
      generationParamsNotifierProvider.select(selectImg2ImgPanelViewData),
    );
    final workflow = ref.watch(imageWorkflowControllerProvider);
    final hasSourceImage = params.sourceImage != null;
    final showBackground = hasSourceImage && !workflow.isPanelExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.img2img_title,
      icon: Icons.image,
      isExpanded: workflow.isPanelExpanded,
      onToggle: () => ref
          .read(imageWorkflowControllerProvider.notifier)
          .setPanelExpanded(!workflow.isPanelExpanded),
      hasData: hasSourceImage,
      backgroundImage: hasSourceImage
          ? DecodedMemoryImage(
              bytes: params.sourceImage!,
              fit: BoxFit.cover,
              decodeScale: 0.5,
            )
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withValues(alpha: 0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.img2img_enabled,
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            _buildSourceImageSection(theme, params, workflow),
            if (hasSourceImage) ...[
              const SizedBox(height: 16),
              if (workflow.isEnhance)
                _buildEnhancePanel(theme, workflow)
              else if (workflow.isInpaint)
                _buildInpaintPanel(theme, params)
              else if (workflow.isUpscale)
                _buildUpscalePanel(theme, workflow)
              else ...[
                _buildStrengthSlider(theme, params),
                const SizedBox(height: 12),
                _buildNoiseSlider(theme, params),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _clearImg2Img,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(context.l10n.img2img_clearSettings),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceImageSection(
    ThemeData theme,
    Img2ImgPanelViewData params,
    ImageWorkflowState workflow,
  ) {
    final hasSourceImage = params.sourceImage != null;
    if (!hasSourceImage) {
      return _buildEmptySourceSection(theme);
    }

    final isInpaintReady = workflow.isInpaint && params.maskImage != null;
    final sourceDimensions =
        _resolveSourceDimensions(workflow, params.sourceImage!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              context.l10n.img2img_sourceImage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const Spacer(),
            _IconButton(
              icon: Icons.refresh,
              onPressed: _pickImage,
              tooltip: context.l10n.img2img_changeImage,
            ),
            const SizedBox(width: 8),
            _IconButton(
              icon: Icons.close,
              onPressed: _removeSourceImage,
              tooltip: context.l10n.img2img_removeImage,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 280,
            child: _SourceImagePreview(
              sourceBytes: params.sourceImage!,
              maskBytes: params.maskImage,
              focusedInpaintEnabled:
                  workflow.isInpaint && workflow.focusedInpaintEnabled,
              focusedSelectionRect: workflow.focusedSelectionRect,
              minimumContextMegaPixels: workflow.minimumContextMegaPixels,
              imageWidth: sourceDimensions.$1,
              imageHeight: sourceDimensions.$2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OperationChip(
              icon: Icons.edit_outlined,
              label: context.l10n.img2img_editImage,
              onPressed: () => ImageWorkflowLauncher.openEditor(
                context,
                ref,
                params.sourceImage!,
                mode: ImageEditorMode.edit,
              ),
            ),
            _OperationChip(
              icon: isInpaintReady ? Icons.check_circle : Icons.draw_outlined,
              label: context.l10n.img2img_inpaint,
              selected: workflow.isInpaint,
              onPressed: () => ImageWorkflowLauncher.openEditor(
                context,
                ref,
                params.sourceImage!,
                mode: ImageEditorMode.inpaint,
              ),
            ),
            _OperationChip(
              icon: Icons.auto_awesome_motion_outlined,
              label: context.l10n.img2img_generateVariations,
              onPressed: () => ImageWorkflowLauncher.generateVariations(
                context,
                ref,
                params.sourceImage!,
              ),
            ),
            _OperationChip(
              icon: Icons.auto_fix_high_outlined,
              label: context.l10n.img2img_directorTools,
              onPressed: () => ImageWorkflowLauncher.openDirectorTools(
                context,
                ref,
                params.sourceImage!,
              ),
            ),
            _OperationChip(
              icon: workflow.isEnhance
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
              label: context.l10n.img2img_enhance,
              selected: workflow.isEnhance,
              onPressed: () => _toggleEnhance(workflow),
            ),
            _OperationChip(
              icon: workflow.isUpscale
                  ? Icons.zoom_out_map
                  : Icons.zoom_out_map_rounded,
              label: context.l10n.image_upscale,
              selected: workflow.isUpscale,
              onPressed: () => _toggleUpscale(workflow),
            ),
            ..._buildComfyUIChips(params),
          ],
        ),
        if (workflow.isInpaint) ...[
          const SizedBox(height: 10),
          _buildInpaintStatus(theme, isInpaintReady),
        ],
      ],
    );
  }

  Widget _buildEmptySourceSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.img2img_sourceImage,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ImagePickerCard(
                icon: Icons.upload_file,
                label: context.l10n.img2img_uploadImage,
                height: 80,
                onImageSelected: (bytes, fileName, path) {
                  ref
                      .read(imageWorkflowControllerProvider.notifier)
                      .replaceSourceImage(bytes);
                },
                onError: (error) {
                  AppToast.error(
                    context,
                    context.l10n.img2img_selectFailed(error),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ImagePickerCard(
                icon: Icons.brush,
                label: context.l10n.img2img_drawSketch,
                height: 80,
                enableDragDrop: false,
                onTap: _openBlankCanvas,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInpaintStatus(ThemeData theme, bool isReady) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isReady
                  ? context.l10n.img2img_inpaintReadyHint
                  : context.l10n.img2img_inpaintPendingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orangeAccent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthSlider(ThemeData theme, Img2ImgPanelViewData params) {
    return _buildSliderSection(
      theme,
      label: context.l10n.img2img_strength,
      value: params.strength,
      hint: context.l10n.img2img_strengthHint,
      onChanged: (value) {
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updateStrength(value);
      },
    );
  }

  Widget _buildNoiseSlider(ThemeData theme, Img2ImgPanelViewData params) {
    return _buildSliderSection(
      theme,
      label: context.l10n.img2img_noise,
      value: params.noise,
      hint: context.l10n.img2img_noiseHint,
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier).updateNoise(value);
      },
    );
  }

  Widget _buildInpaintPanel(ThemeData theme, Img2ImgPanelViewData params) {
    final workflow = ref.watch(imageWorkflowControllerProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSliderSection(
            theme,
            label: context.l10n.img2img_inpaintStrength,
            value: params.inpaintStrength,
            hint: context.l10n.img2img_inpaintStrengthHint,
            onChanged: (value) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateInpaintStrength(value);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Focused Inpainting（聚焦重绘）',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              workflow.focusedInpaintEnabled
                  ? '已启用。请在重绘编辑器左上角按钮里调整聚焦区域与 Minimum Context Area。'
                  : '默认是普通重绘；如需聚焦重绘，请在重绘编辑器左上角按钮中开启并框选区域。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: workflow.focusedInpaintEnabled
                    ? Colors.cyanAccent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: workflow.focusedInpaintEnabled
                      ? Colors.cyanAccent.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                workflow.focusedInpaintEnabled ? '已启用' : '未启用',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: workflow.focusedInpaintEnabled
                      ? Colors.cyanAccent
                      : Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (int, int) _resolveSourceDimensions(
    ImageWorkflowState workflow,
    Uint8List sourceBytes,
  ) {
    final width = workflow.sourceWidth;
    final height = workflow.sourceHeight;
    if (width != null && height != null) {
      return (width, height);
    }

    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return (1, 1);
    }
    return (decoded.width, decoded.height);
  }

  Widget _buildSliderSection(
    ThemeData theme, {
    required String label,
    required double value,
    ValueChanged<double>? onChanged,
    String? hint,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
    String Function(double value)? valueLabelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              valueLabelBuilder?.call(value) ?? value.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? ((max - min) * 100).round(),
            onChanged: onChanged,
          ),
        ),
        if (hint != null)
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancePanel(
    ThemeData theme,
    ImageWorkflowState workflow,
  ) {
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    final enhance = workflow.enhance;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.img2img_enhance,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.img2img_enhanceHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildSliderSection(
            theme,
            label: context.l10n.img2img_enhanceMagnitude,
            value: enhance.magnitude,
            onChanged: controller.updateEnhanceMagnitude,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.img2img_enhanceShowIndividualSettings,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            value: enhance.showIndividualSettings,
            onChanged: controller.toggleEnhanceIndividualSettings,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.img2img_enhanceUpscaleAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1.0, 1.5].map((factor) {
              final label = factor == 1.0 ? '1x' : '1.5x';
              return ChoiceChip(
                label: Text(label),
                selected: enhance.upscaleFactor == factor,
                onSelected: (_) =>
                    controller.updateEnhanceUpscaleFactor(factor),
              );
            }).toList(),
          ),
          if (enhance.showIndividualSettings) ...[
            const SizedBox(height: 12),
            _buildSliderSection(
              theme,
              label: context.l10n.img2img_strength,
              value: enhance.strength,
              onChanged: (value) => controller.updateEnhanceIndividualSettings(
                strength: value,
              ),
            ),
            const SizedBox(height: 12),
            _buildSliderSection(
              theme,
              label: context.l10n.img2img_noise,
              value: enhance.noise,
              onChanged: (value) => controller.updateEnhanceIndividualSettings(
                noise: value,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpscalePanel(ThemeData theme, ImageWorkflowState workflow) {
    final comfyEnabled =
        ref.watch(comfyUISettingsProvider.select((s) => s.enabled));
    final taskState = ref.watch(comfyUITaskProvider);
    final hasSourceImage = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.sourceImage != null,
      ),
    );
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    final upscale = workflow.upscale;
    final isNai = upscale.backend == UpscaleBackend.novelai;
    final isComfy = upscale.backend == UpscaleBackend.comfyui;
    final isLocalOnnx = upscale.backend == UpscaleBackend.localOnnx;

    final availableModels = ref.watch(comfyUISeedvr2ModelsProvider);
    final resolvedComfyModel = selectPreferredUpscaleModel(
      availableModels,
      currentModel: upscale.comfyModel,
    );

    if (isComfy &&
        availableModels.isNotEmpty &&
        resolvedComfyModel != upscale.comfyModel) {
      Future.microtask(
        () => controller.updateUpscaleComfyModel(resolvedComfyModel),
      );
    }

    final bool canStart;
    if (isNai) {
      canStart = hasSourceImage && !_naiUpscaling;
    } else if (isLocalOnnx) {
      canStart = hasSourceImage && !_localOnnxUpscaling;
    } else {
      canStart = comfyEnabled && hasSourceImage && !taskState.isRunning;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.image_upscale,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<UpscaleBackend>(
            segments: [
              const ButtonSegment(
                value: UpscaleBackend.novelai,
                label: Text('NovelAI'),
                icon: Icon(Icons.cloud_outlined, size: 16),
              ),
              ButtonSegment(
                value: UpscaleBackend.comfyui,
                label: const Text('ComfyUI'),
                icon: const Icon(Icons.computer, size: 16),
                enabled: comfyEnabled,
              ),
              const ButtonSegment(
                value: UpscaleBackend.localOnnx,
                label: Text('本地 ONNX'),
                icon: Icon(Icons.memory_rounded, size: 16),
              ),
            ],
            selected: {upscale.backend},
            onSelectionChanged: (v) => controller.updateUpscaleBackend(v.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 12),
          if (isNai) ...[
            Text(
              'NovelAI 云端超分 (固定 4× 放大)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ] else if (isLocalOnnx) ...[
            Text(
              '本地轻量放大使用模型文件夹列表选择模型，倍率由 Lanczos3 缩放实现。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<LocalOnnxModelDescriptor>>(
              future:
                  ref.read(localOnnxModelServiceProvider).scanUpscaleModels(),
              builder: (context, snapshot) {
                final models =
                    snapshot.data ?? const <LocalOnnxModelDescriptor>[];
                final selected =
                    models.any((m) => m.path == upscale.localOnnxModel)
                        ? upscale.localOnnxModel
                        : (models.isNotEmpty ? models.first.path : null);
                if (selected != null && selected != upscale.localOnnxModel) {
                  Future.microtask(
                    () => controller.updateUpscaleLocalOnnxModel(selected),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: models
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.path,
                          child: Text(
                            m.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      controller.updateUpscaleLocalOnnxModel(v);
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: '本地 ONNX 模型',
                    hintText: '请在设置中配置模型文件夹',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildScaleSlider(theme, upscale, controller),
            if (_localOnnxUpscaling) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ] else ...[
            if (!comfyEnabled)
              Text(
                '请先在「设置 → ComfyUI」中启用并连接服务器。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orangeAccent,
                ),
              )
            else ...[
              Text(
                '超分模型',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('upscale_model_${availableModels.length}'),
                initialValue: availableModels.contains(resolvedComfyModel)
                    ? resolvedComfyModel
                    : (availableModels.isNotEmpty
                        ? availableModels.first
                        : null),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                items: availableModels
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          _friendlyModelName(m),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) controller.updateUpscaleComfyModel(v);
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(comfyUISeedvr2ModelsProvider.notifier).fetch(),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(
                    '刷新模型列表',
                    style: theme.textTheme.labelSmall,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _buildScaleSlider(theme, upscale, controller),
              const SizedBox(height: 8),
              if (taskState.isRunning) ...[
                if (taskState.hasPreview) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      taskState.previewImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const LinearProgressIndicator(),
              ] else if (taskState.status == ComfyUITaskStatus.failed &&
                  taskState.errorMessage != null)
                Text(
                  taskState.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ],
          if (_naiUpscaling) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canStart ? _runUpscale : null,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('开始超分'),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleSlider(
    ThemeData theme,
    UpscaleWorkflowSettings upscale,
    ImageWorkflowController controller,
  ) {
    final value = upscale.comfyScale.clamp(
      UpscaleWorkflowSettings.minScale,
      UpscaleWorkflowSettings.maxScale,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '放大倍数',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            EditableDoubleField(
              value: value,
              min: UpscaleWorkflowSettings.minScale,
              max: UpscaleWorkflowSettings.maxScale,
              decimals: 1,
              width: 60,
              onChanged: controller.updateUpscaleComfyScale,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: UpscaleWorkflowSettings.minScale,
            max: UpscaleWorkflowSettings.maxScale,
            divisions: 10,
            onChanged: controller.updateUpscaleComfyScale,
          ),
        ),
      ],
    );
  }

  static String _friendlyModelName(String filename) {
    final base =
        filename.replaceAll('.safetensors', '').replaceAll('.ckpt', '');
    return base;
  }

  Future<void> _runUpscale() async {
    final params = ref.read(generationParamsNotifierProvider);
    final src = params.sourceImage;
    if (src == null) return;

    final wf = ref.read(imageWorkflowControllerProvider);

    if (wf.upscale.backend == UpscaleBackend.novelai) {
      await _runNaiUpscale(params, src);
    } else if (wf.upscale.backend == UpscaleBackend.localOnnx) {
      await _runLocalOnnxUpscale(params, src, wf);
    } else {
      await _runComfySeedvr2Upscale(params, src, wf);
    }
  }

  Future<void> _runNaiUpscale(ImageParams params, Uint8List src) async {
    setState(() => _naiUpscaling = true);
    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final result = await apiService.upscaleImage(src, scale: 4);
      if (!mounted) return;

      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .registerExternalImage(
            result,
            params: params,
            saveToLocal: saveSettings.autoSave,
            addToDisplay: true,
          );
      if (mounted) AppToast.success(context, 'NovelAI 超分完成');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _naiUpscaling = false);
    }
  }

  Future<void> _runComfySeedvr2Upscale(
    ImageParams params,
    Uint8List src,
    ImageWorkflowState wf,
  ) async {
    final scale = wf.upscale.comfyScale;
    final model = wf.upscale.comfyModel;

    final results = await ref.read(comfyUITaskProvider.notifier).execute(
      templateId: 'builtin_seedvr2_upscale',
      inputImages: {'input_image': src},
      paramValues: {
        'scale_multiplier': scale,
        'dit_model': model,
        'seed': -1,
      },
    );

    if (!mounted || results == null || results.isEmpty) return;

    final bytes = results.last;

    final decoded = img.decodeImage(bytes);
    final srcDecoded = decoded == null ? img.decodeImage(src) : null;
    final outW = decoded?.width ??
        (srcDecoded != null
            ? (srcDecoded.width * scale).round()
            : params.width);
    final outH = decoded?.height ??
        (srcDecoded != null
            ? (srcDecoded.height * scale).round()
            : params.height);

    final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
    await ref
        .read(imageGenerationNotifierProvider.notifier)
        .registerExternalImage(
          bytes,
          params: params,
          width: outW,
          height: outH,
          saveToLocal: saveSettings.autoSave,
          addToDisplay: true,
        );

    if (mounted) {
      AppToast.success(context, '超分完成 ($outW×$outH)，已加入预览列表');
    }
  }

  Future<void> _runLocalOnnxUpscale(
    ImageParams params,
    Uint8List src,
    ImageWorkflowState wf,
  ) async {
    setState(() => _localOnnxUpscaling = true);
    try {
      final models =
          await ref.read(localOnnxModelServiceProvider).scanUpscaleModels();
      if (models.isEmpty) {
        throw StateError('未找到本地 ONNX 放大模型，请先在设置中配置模型文件夹');
      }
      final selectedModel =
          models.any((m) => m.path == wf.upscale.localOnnxModel)
              ? wf.upscale.localOnnxModel
              : models.first.path;
      ref
          .read(imageWorkflowControllerProvider.notifier)
          .updateUpscaleLocalOnnxModel(selectedModel);

      final result = await ref
          .read(localOnnxUpscaleServiceProvider)
          .upscaleLanczos(imageBytes: src, scale: wf.upscale.comfyScale);
      if (!mounted) return;

      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .registerExternalImage(
            result.bytes,
            params: params,
            width: result.width,
            height: result.height,
            saveToLocal: saveSettings.autoSave,
            addToDisplay: true,
          );

      if (mounted) {
        AppToast.success(
          context,
          '本地 Lanczos 超分完成 (${result.width}×${result.height})',
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _localOnnxUpscaling = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          ref
              .read(imageWorkflowControllerProvider.notifier)
              .replaceSourceImage(bytes);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  void _removeSourceImage() {
    ref.read(imageWorkflowControllerProvider.notifier).clearSourceImage();
  }

  void _clearImg2Img() {
    _removeSourceImage();
  }

  List<Widget> _buildComfyUIChips(Img2ImgPanelViewData params) {
    final bool comfyEnabled;
    try {
      comfyEnabled =
          ref.watch(comfyUISettingsProvider.select((s) => s.enabled));
    } catch (_) {
      return [];
    }
    if (!comfyEnabled) return [];

    final List<WorkflowTemplate> workflows;
    try {
      workflows = ref.watch(comfyUIWorkflowsProvider);
    } catch (_) {
      return [];
    }
    final eligibleWorkflows = workflows
        .where(
          (t) => t.id != 'builtin_seedvr2_upscale' && t.requiresInputImage,
        )
        .toList();

    if (eligibleWorkflows.isEmpty) return [];

    return eligibleWorkflows.map<Widget>((template) {
      final icon = switch (template.category) {
        WorkflowCategory.img2img => Icons.image_outlined,
        WorkflowCategory.inpaint => Icons.draw_outlined,
        WorkflowCategory.enhance => Icons.auto_fix_high_outlined,
        _ => Icons.account_tree_outlined,
      };
      return _OperationChip(
        icon: icon,
        label: template.name,
        onPressed: () => ComfyUIWorkflowDialog.show(
          context,
          template: template,
          image: params.sourceImage,
        ),
      );
    }).toList();
  }

  void _toggleEnhance(ImageWorkflowState workflow) {
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    if (workflow.isEnhance) {
      controller.exitEnhanceMode();
    } else {
      controller.enterEnhanceMode();
    }
  }

  void _toggleUpscale(ImageWorkflowState workflow) {
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    if (workflow.isUpscale) {
      controller.exitUpscaleMode();
    } else {
      controller.enterUpscaleMode();
    }
  }

  Future<void> _openBlankCanvas() async {
    final params = ref.read(generationParamsNotifierProvider);
    final canvasSize = Size(
      params.width.toDouble(),
      params.height.toDouble(),
    );

    final result = await ImageEditorScreen.show(
      context,
      initialSize: canvasSize,
      mode: ImageEditorMode.edit,
      title: context.l10n.img2img_drawSketch,
    );

    if (result != null && result.modifiedImage != null && mounted) {
      ref
          .read(imageWorkflowControllerProvider.notifier)
          .replaceSourceImage(result.modifiedImage!);
      ref.read(imageWorkflowControllerProvider.notifier).setPanelExpanded(true);
    }
  }
}

class _OperationChip extends StatelessWidget {
  const _OperationChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceImagePreview extends StatefulWidget {
  const _SourceImagePreview({
    required this.sourceBytes,
    required this.imageWidth,
    required this.imageHeight,
    this.maskBytes,
    this.focusedInpaintEnabled = false,
    this.focusedSelectionRect,
    this.minimumContextMegaPixels = 88.0,
  });

  final Uint8List sourceBytes;
  final Uint8List? maskBytes;
  final bool focusedInpaintEnabled;
  final Rect? focusedSelectionRect;
  final double minimumContextMegaPixels;
  final int imageWidth;
  final int imageHeight;

  @override
  State<_SourceImagePreview> createState() => _SourceImagePreviewState();
}

class _SourceImagePreviewState extends State<_SourceImagePreview> {
  final Img2ImgPreviewCache _previewCache = Img2ImgPreviewCache();
  Img2ImgPreviewDerivedData _derivedData = const Img2ImgPreviewDerivedData();

  @override
  void initState() {
    super.initState();
    _syncDerivedData();
  }

  @override
  void didUpdateWidget(covariant _SourceImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDerivedData();
  }

  void _syncDerivedData() {
    _derivedData = _previewCache.resolve(
      sourceImage: widget.sourceBytes,
      maskImage: widget.maskBytes,
      focusedInpaintEnabled: widget.focusedInpaintEnabled,
      focusedSelectionRect: widget.focusedSelectionRect,
      minContextMegaPixels: widget.minimumContextMegaPixels,
      sourceWidth: widget.imageWidth,
      sourceHeight: widget.imageHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containedSize = _resolveContainedSize(
            imageWidth: widget.imageWidth.toDouble(),
            imageHeight: widget.imageHeight.toDouble(),
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
          );

          return Center(
            child: SizedBox(
              width: containedSize.width,
              height: containedSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecodedMemoryImage(
                    bytes: widget.sourceBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    maxLogicalWidth: containedSize.width,
                    maxLogicalHeight: containedSize.height,
                  ),
                  if (_derivedData.maskOverlayBytes != null)
                    IgnorePointer(
                      child: DecodedMemoryImage(
                        bytes: _derivedData.maskOverlayBytes!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        maxLogicalWidth: containedSize.width,
                        maxLogicalHeight: containedSize.height,
                      ),
                    ),
                  if (_derivedData.focusedFrame?.contextCrop != null)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _FocusedCropOverlayPainter(
                          crop: _derivedData.focusedFrame!.contextCrop,
                          focusBounds: _derivedData.focusedFrame!.focusBounds,
                          imageWidth: widget.imageWidth,
                          imageHeight: widget.imageHeight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Size _resolveContainedSize({
    required double imageWidth,
    required double imageHeight,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      return Size(maxWidth, maxHeight);
    }

    final scale = math.min(maxWidth / imageWidth, maxHeight / imageHeight);
    return Size(imageWidth * scale, imageHeight * scale);
  }
}

class _FocusedCropOverlayPainter extends CustomPainter {
  const _FocusedCropOverlayPainter({
    required this.crop,
    required this.focusBounds,
    required this.imageWidth,
    required this.imageHeight,
  });

  final FocusedInpaintCrop crop;
  final FocusedInpaintCrop? focusBounds;
  final int imageWidth;
  final int imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final contextRect = Rect.fromLTWH(
      crop.x / imageWidth * size.width,
      crop.y / imageHeight * size.height,
      crop.width / imageWidth * size.width,
      crop.height / imageHeight * size.height,
    );
    final contextPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(contextRect, const Radius.circular(2)),
      );

    if (focusBounds != null) {
      final selectionRect = Rect.fromLTWH(
        focusBounds!.x / imageWidth * size.width,
        focusBounds!.y / imageHeight * size.height,
        focusBounds!.width / imageWidth * size.width,
        focusBounds!.height / imageHeight * size.height,
      );
      final focusPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(selectionRect, const Radius.circular(2)),
        );
      FocusedOverlayPainter(
        contextPath: contextPath,
        focusPath: focusPath,
      ).paint(canvas, size);
      return;
    }

    FocusedOverlayPainter(
      contextPath: contextPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedCropOverlayPainter oldDelegate) {
    return crop.x != oldDelegate.crop.x ||
        crop.y != oldDelegate.crop.y ||
        crop.width != oldDelegate.crop.width ||
        crop.height != oldDelegate.crop.height ||
        focusBounds?.x != oldDelegate.focusBounds?.x ||
        focusBounds?.y != oldDelegate.focusBounds?.y ||
        focusBounds?.width != oldDelegate.focusBounds?.width ||
        focusBounds?.height != oldDelegate.focusBounds?.height ||
        imageWidth != oldDelegate.imageWidth ||
        imageHeight != oldDelegate.imageHeight;
  }
}

/// 小型图标按钮
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
