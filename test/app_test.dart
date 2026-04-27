import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/core/comfyui/comfyui_url_utils.dart';
import 'package:nai_launcher/data/services/local_onnx_upscale_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

/// 简单的 Widget 测试示例
///
/// 运行: flutter test test/app_test.dart
void main() {
  group('Widget Tests', () {
    testWidgets('MaterialApp 创建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('按钮点击', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () => pressed = true,
              child: const Text('Click'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('AppBootstrapEffects 监听 provider 变化时不重建子树', (tester) async {
      final anlasWatcherProvider = StateProvider<int>((ref) => 0);
      final backgroundRefreshProvider = StateProvider<int>((ref) => 0);
      var buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppBootstrapEffects(
              anlasWatcher: anlasWatcherProvider,
              backgroundRefresh: backgroundRefreshProvider,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppBootstrapEffects)),
      );

      expect(container.exists(anlasWatcherProvider), isTrue);
      expect(container.exists(backgroundRefreshProvider), isTrue);
      expect(buildCount, 1);

      container.read(anlasWatcherProvider.notifier).state = 1;
      await tester.pump();
      container.read(backgroundRefreshProvider.notifier).state = 1;
      await tester.pump();

      expect(buildCount, 1);
    });
  });

  group('ComfyUI URL helpers', () {
    test('normalizes pasted server URLs without breaking scheme typing', () {
      expect(
        normalizeComfyUIBaseUrl('  http://127.0.0.1:8188/  '),
        'http://127.0.0.1:8188',
      );
      expect(
        normalizeComfyUIBaseUrl('https://example.test/comfyui///'),
        'https://example.test/comfyui',
      );
      expect(normalizeComfyUIBaseUrl('http://'), 'http://');
      expect(normalizeComfyUIBaseUrl('https://'), 'https://');
    });

    test('builds websocket URLs without double slashes', () {
      final rootUri = buildComfyUIWebSocketUri(
        baseUrl: 'http://127.0.0.1:8188/',
        clientId: 'client-1',
      );
      final proxiedUri = buildComfyUIWebSocketUri(
        baseUrl: 'https://example.test/comfyui/',
        clientId: 'client-1',
      );

      expect(rootUri.toString(), 'ws://127.0.0.1:8188/ws?clientId=client-1');
      expect(
        proxiedUri.toString(),
        'wss://example.test/comfyui/ws?clientId=client-1',
      );
    });
  });

  group('Prompt assistant defaults', () {
    test('contains immutable defaults for all assistant task types', () {
      final defaults = PromptAssistantConfigState.defaults();

      for (final taskType in AssistantTaskType.values) {
        expect(
          defaults.models.any(
            (model) => model.forTask == taskType && model.isDefault,
          ),
          isTrue,
        );
        expect(
          defaults.rules.any(
            (rule) => rule.taskType == taskType && rule.isDefault,
          ),
          isTrue,
        );
        expect(defaults.routing.providerIdFor(taskType), isNotEmpty);
        expect(defaults.routing.modelFor(taskType), isNotEmpty);
      }
    });

    test(
      'hydrates reverse and character replacement routing from old config',
      () {
        final oldConfig = PromptAssistantConfigState.defaults()
            .copyWith(
              models: PromptAssistantConfigState.defaults()
                  .models
                  .where(
                    (model) =>
                        model.forTask == AssistantTaskType.llm ||
                        model.forTask == AssistantTaskType.translate,
                  )
                  .toList(),
              rules: PromptAssistantConfigState.defaults()
                  .rules
                  .where(
                    (rule) =>
                        rule.taskType == AssistantTaskType.llm ||
                        rule.taskType == AssistantTaskType.translate,
                  )
                  .toList(),
            )
            .toJson()
          ..['routing'] = const TaskRoutingConfig(
            llmProviderId: 'pollinations',
            llmModel: 'openai-large',
            translateProviderId: 'pollinations',
            translateModel: 'openai-large',
            reverseProviderId: '',
            reverseModel: '',
            characterReplaceProviderId: '',
            characterReplaceModel: '',
          ).toJson();

        final decoded = PromptAssistantConfigState.decode(
          PromptAssistantConfigState(
            enabled: oldConfig['enabled'] as bool,
            desktopOverlayEnabled: oldConfig['desktopOverlayEnabled'] as bool,
            streamOutput: oldConfig['streamOutput'] as bool,
            providers: (oldConfig['providers'] as List)
                .cast<Map<String, dynamic>>()
                .map(ProviderConfig.fromJson)
                .toList(),
            models: (oldConfig['models'] as List)
                .cast<Map<String, dynamic>>()
                .map(ModelConfig.fromJson)
                .toList(),
            routing: TaskRoutingConfig.fromJson(
              (oldConfig['routing'] as Map).cast<String, dynamic>(),
            ),
            rules: (oldConfig['rules'] as List)
                .cast<Map<String, dynamic>>()
                .map(PromptRuleTemplate.fromJson)
                .toList(),
            providerHasApiKey: const {},
          ).encode(),
        );

        expect(
          decoded.models.any(
            (model) => model.forTask == AssistantTaskType.reverse,
          ),
          isTrue,
        );
        expect(
          decoded.models.any(
            (model) => model.forTask == AssistantTaskType.characterReplace,
          ),
          isTrue,
        );
        expect(
          decoded.rules.any(
            (rule) => rule.taskType == AssistantTaskType.reverse,
          ),
          isTrue,
        );
        expect(
          decoded.rules.any(
            (rule) => rule.taskType == AssistantTaskType.characterReplace,
          ),
          isTrue,
        );
        expect(
          decoded.routing.providerIdFor(AssistantTaskType.reverse),
          isNotEmpty,
        );
        expect(
          decoded.routing.providerIdFor(AssistantTaskType.characterReplace),
          isNotEmpty,
        );
      },
    );
  });

  group('Local ONNX upscale', () {
    test('uses Lanczos scaling dimensions for local image upscale', () async {
      final source = img.Image(width: 2, height: 3);
      img.fill(source, color: img.ColorRgb8(24, 48, 96));
      const service = LocalOnnxUpscaleService();

      final result = await service.upscaleLanczos(
        imageBytes: Uint8List.fromList(img.encodePng(source)),
        scale: 2,
      );
      final decoded = img.decodePng(result.bytes);

      expect(result.width, 4);
      expect(result.height, 6);
      expect(decoded?.width, 4);
      expect(decoded?.height, 6);
    });
  });
}
