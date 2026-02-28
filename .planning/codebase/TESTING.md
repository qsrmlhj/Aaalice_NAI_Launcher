# 测试模式

**分析日期:** 2026-02-28

## 测试框架

**测试运行器:**
- `flutter_test` - Flutter SDK 自带测试框架
- 配置文件: 使用默认配置，无自定义 `test_config.dart`

**断言库:**
- `flutter_test` 内置 `expect()` 函数
- 匹配器: `equals()`, `isTrue`, `isFalse`, `isNull`, `isNotNull`, `isEmpty`, `isNotEmpty`
- 类型匹配: `isA<T>()`, `throwsA()`
- 集合匹配: `contains()`, `hasLength()`, `orderedEquals()`

**Mock 框架:**
- `mocktail: ^1.0.3` - 类型安全的 Mock 框架
- 使用 `Mock` 基类创建 Mock 对象
- 使用 `when()` 和 `verify()` 定义存根和验证
- `registerFallbackValue()` 注册备用值

**属性基测试:**
- `glados: ^1.1.1` - 属性基测试框架（配置但未广泛使用）

**运行命令:**
```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/app_logger_test.dart
flutter test test/core/services/parameter_processing_service_test.dart

# 运行特定组
test('should create with default empty lists', () { ... });

# 查看详细输出
flutter test --verbose
```

## 测试文件组织

**位置:**
- 测试文件位于 `/test` 目录
- 与 `lib/` 目录结构镜像对应
- 测试文件使用 `*_test.dart` 后缀

**结构:**
```
test/
├── app_test.dart                          # 基础 Widget 测试
├── app_logger_test.dart                   # 日志系统测试
├── data_source_test.dart                  # 数据源测试
├── data_sources_initialization_test.dart  # 集成测试
├── first_launch_test.dart                 # 首次启动流程测试
├── translation_debug_test.dart            # 翻译调试测试
├── core/
│   ├── database/
│   │   ├── asset_database_test.dart
│   │   ├── cooccurrence_data_source_test.dart
│   │   └── translation_data_source_test.dart
│   ├── services/
│   │   ├── danbooru_tags_lazy_service_test.dart
│   │   ├── image_generation_service_test.dart
│   │   └── parameter_processing_service_test.dart
│   └── utils/
│       ├── app_logger_test.dart
│       └── vibe_image_embedder_test.dart
├── data/
│   └── models/
│       ├── character/character_reference_test.dart
│       └── image/image_params_test.dart
└── fixtures/
    └── vibe_samples/                      # 测试固件
```

**命名规范:**
- 测试文件: `{source_file}_test.dart`
- 测试组: `group('ClassName', () { ... })`
- 测试用例: `test('should do something', () { ... })`

## 测试结构

**基本结构:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/parameter_processing_service.dart';

void main() {
  group('ParameterProcessingService', () {
    group('constructor', () {
      test('should create with default empty lists', () {
        final service = ParameterProcessingService();

        expect(service.tagLibraryEntries, isEmpty);
        expect(service.fixedTags, isEmpty);
      });
    });

    group('process - basic', () {
      test('should return unprocessed result when both flags are false', () {
        // Arrange
        final service = ParameterProcessingService();
        const prompt = 'test prompt';

        // Act
        final result = service.process(
          prompt: prompt,
          resolveAliases: false,
          applyFixedTags: false,
        );

        // Assert
        expect(result.prompt, equals(prompt));
        expect(result.aliasesResolved, isFalse);
      });
    });
  });
}
```

**生命周期:**
```dart
void main() {
  setUpAll(() {
    // 所有测试前执行一次
    registerFallbackValue(const ImageParams());
  });

  setUp(() {
    // 每个测试前执行
    mockApiService = MockNAIImageGenerationApiService();
    service = ImageGenerationService(apiService: mockApiService);
  });

  tearDown(() {
    // 每个测试后执行
    reset(mockApiService);
  });

  tearDownAll(() {
    // 所有测试后执行一次
  });
}
```

**异步测试:**
```dart
test('should return successful result with generated image', () async {
  when(() => mockApiService.generateImageStream(any()))
      .thenAnswer((_) => Stream.value(ImageStreamChunk.complete(imageBytes)));

  final result = await service.generateSingle(params);

  expect(result.isSuccess, isTrue);
});
```

## Mocking 模式

**创建 Mock:**
```dart
import 'package:mocktail/mocktail.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class FakeImageParams extends Fake implements ImageParams {}
```

**配置 Mock:**
```dart
setUpAll(() {
  registerFallbackValue(const ImageParams());
  registerFallbackValue(FakeImageParams());
});

setUp(() {
  mockApiService = MockNAIImageGenerationApiService();
  service = ImageGenerationService(apiService: mockApiService);
});
```

**定义存根:**
```dart
// 同步返回值
when(() => mockApiService.cancelGeneration()).thenReturn(null);

// 异步返回值
when(() => mockApiService.generateImageStream(any()))
    .thenAnswer((_) => Stream.value(ImageStreamChunk.complete(imageBytes)));

// 抛出异常
when(() => mockApiService.generateImageStream(any()))
    .thenAnswer((_) => Stream.error(Exception('Stream error')));
```

**验证调用:**
```dart
// 验证调用次数
verify(() => mockApiService.cancelGeneration()).called(1);

// 验证从未调用
verifyNever(() => mockApiService.generateImage(any()));

// 验证调用参数
verify(() => mockApiService.generateImage(
  any(),
  onProgress: any(named: 'onProgress'),
)).called(1);
```

**重置 Mock:**
```dart
tearDown(() {
  reset(mockApiService);  // 清除所有存根和验证状态
});
```

## Fixtures 和 Factories

**测试数据:**
```dart
// 内联创建
final entries = [
  TagLibraryEntry.create(name: 'test1', content: 'content1'),
];

// 使用模型工厂方法
final fixedTags = [
  FixedTagEntry.create(
    name: 'prefix1',
    content: 'prefix content',
    position: FixedTagPosition.prefix,
  ),
];
```

**固件文件:**
- 位置: `test/fixtures/`
- 类型: 图片文件、JSON 数据、二进制数据
- 使用: 直接读取文件系统加载

## 覆盖率

**当前状态:**
- 无强制覆盖率要求
- 关键服务有单元测试覆盖
- 模型类有属性测试覆盖

**测试类型分布:**
- 单元测试: 80% (服务、模型、工具类)
- 集成测试: 15% (数据源初始化、流程验证)
- Widget 测试: 5% (基础组件)

**查看覆盖率:**
```bash
# 生成覆盖率报告
flutter test --coverage

# 查看 HTML 报告
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 常见测试模式

**服务测试:**
```dart
group('ParameterProcessingService', () {
  group('constructor', () { ... });
  group('process - basic', () { ... });
  group('process - alias resolution', () { ... });
  group('process - fixed tags', () { ... });
});
```

**模型测试:**
```dart
group('ImageParams preciseReference getters', () {
  test('preciseReferenceCount should return 0 when no references', () {
    const params = ImageParams();
    expect(params.preciseReferenceCount, equals(0));
  });

  test('preciseReferenceCost should return 5 with single reference', () {
    final params = ImageParams(
      preciseReferences: [PreciseReference(...)],
    );
    expect(params.preciseReferenceCost, equals(5));
  });
});
```

**异步测试:**
```dart
test('should return error result when stream throws error', () async {
  when(() => mockApiService.generateImageStream(any()))
      .thenAnswer((_) => Stream.error(Exception('Stream error')));

  final result = await service.generateSingle(params);

  expect(result.isSuccess, isFalse);
  expect(result.error, isNotNull);
});
```

**日志验证:**
```dart
test('日志内容正确写入', () async {
  AppLogger.i('测试消息', 'Test');
  await Future.delayed(const Duration(milliseconds: 100));

  final logFile = File(AppLogger.currentLogFile!);
  final content = await logFile.readAsString();

  expect(content, contains('测试消息'));
  expect(content, contains('[Test]'));
});
```

## 测试工具

**日志测试:**
```dart
// 初始化测试环境日志
await AppLogger.initialize(isTestEnvironment: true);

// 验证测试前缀
expect(AppLogger.currentLogFile, contains('test_'));
```

**文件系统测试:**
```dart
final logFile = File(AppLogger.currentLogFile!);
final content = await logFile.readAsString();
expect(content.length, greaterThan(0));
```

## 已知限制

**Mock 限制:**
- 需要 `registerFallbackValue()` 处理可选参数
- 复杂泛型类型需要创建 Fake 类

**异步测试:**
- 文件写入需要延迟等待 `Future.delayed()`
- Stream 测试需要小心时序控制

**覆盖率缺口:**
- UI 页面测试覆盖率低
- Riverpod Provider 测试较少
- 集成测试需要更多真实环境

---

*测试分析: 2026-02-28*
