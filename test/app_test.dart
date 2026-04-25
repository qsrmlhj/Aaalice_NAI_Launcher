import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/core/comfyui/comfyui_url_utils.dart';

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
}
