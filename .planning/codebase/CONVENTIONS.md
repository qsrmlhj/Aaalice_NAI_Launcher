# 编码规范

**分析日期:** 2026-02-28

## 命名规范

**文件命名:**
- 小写下划线命名法: `auth_provider.dart`, `saved_account.dart`, `image_params.dart`
- 生成的文件后缀: `.g.dart` (JSON/Hive/Riverpod), `.freezed.dart` (Freezed 模型)
- 测试文件: `*_test.dart` 后缀，与源文件同名

**类命名:**
- 大驼峰命名法: `AuthProvider`, `SavedAccount`, `ImageParams`
- Controller 类使用 `Notifier` 后缀: `AuthNotifier`, `AccountManagerNotifier`
- 服务类使用 `Service` 后缀: `ImageGenerationService`, `ParameterProcessingService`
- Repository 类使用 `Repository` 后缀
- 数据源类使用 `DataSource` 后缀

**变量命名:**
- 局部变量使用小驼峰: `tagLibraryEntries`, `fixedTags`
- 私有变量以下划线开头: `_logger`, `_fileOutput`
- 常量使用大写下划线: `_maxLogFiles`, `_maxLogFileSize`
- 布尔变量使用 `is`/`has` 前缀: `isAuthenticated`, `hasToken`

**枚举命名:**
- 枚举名大驼峰: `AuthStatus`, `ReplicationTaskSource`
- 枚举值小驼峰: `authenticated`, `unauthenticated`, `online`, `local`

## 代码风格

**格式化:**
- 使用 `flutter_lints` 包作为基础规则
- 强制尾随逗号: `require_trailing_commas: true`
- 优先使用 const 构造函数: `prefer_const_constructors: true`
- 优先使用 const 声明: `prefer_const_declarations: true`
- 优先使用 final 字段: `prefer_final_fields: true`
- 优先使用 final 局部变量: `prefer_final_locals: true`

**字符串规范:**
- 使用单引号优先（除非需要转义）
- 字符串插值: `'$variable'` 或 `'${object.property}'`
- 多行字符串使用三个引号

**集合规范:**
- 使用字面量语法: `[]`, `{}`, 而非 `List()`, `Map()`
- 泛型参数显式声明: `List<String>`, `Map<String, dynamic>`

## 导入组织

**导入顺序:**
1. Dart SDK 导入: `dart:io`, `dart:async`
2. Flutter 包导入: `package:flutter/material.dart`
3. 第三方包导入: `package:flutter_riverpod/flutter_riverpod.dart`
4. 项目内导入: `import '../../core/utils/app_logger.dart'`
5. 相对路径导入: `import 'auth_provider.dart'`

**路径别名:**
- 不使用路径别名，直接使用相对路径
- 上层目录使用 `../../` 语法
- 同级目录使用 `./` 语法

**生成的 part 文件:**
```dart
part 'saved_account.freezed.dart';  // Freezed 生成
part 'saved_account.g.dart';        // JSON/Hive 生成
```

## 错误处理

**异常类型:**
- 自定义异常实现 `Exception` 接口
- 数据库异常: `DataSourceOperationException`, `DatabaseOperationException`
- 连接异常: `ConnectionLeaseException`, `ConnectionInvalidException`

**错误处理模式:**
```dart
try {
  // 操作
} catch (e) {
  AppLogger.w('警告信息', e);
  // 降级处理或重新抛出
}
```

**异步错误处理:**
- 使用 `AsyncValue.guard()` 包装异步操作
- Riverpod 中使用 `AsyncValue` 状态管理
- 服务层捕获并转换为领域错误

## 日志规范

**日志框架:** `AppLogger` (基于 `logger` 包)

**日志级别:**
- `AppLogger.d()` - 调试信息
- `AppLogger.i()` - 一般信息
- `AppLogger.w()` - 警告
- `AppLogger.e()` - 错误
- `AppLogger.network()` - 网络请求
- `AppLogger.auth()` - 认证相关（自动脱敏）

**日志规范:**
- 使用标签分类: `AppLogger.i('消息', 'Tag')`
- 敏感信息自动脱敏（邮箱、Token）
- 日志文件自动轮换，保留最近3个
- 测试环境使用 `test_` 前缀

## 状态管理

**Riverpod 模式:**

函数式 Provider:
```dart
@riverpod
NaiAuthApiService naiAuthApiService(NaiAuthApiServiceRef ref) {
  final dio = ref.watch(dioClientProvider);
  return NaiAuthApiService(dio);
}
```

Controller 模式:
```dart
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<void> build() async { ... }

  Future<void> login() async {
    state = await AsyncValue.guard(() => _login());
  }
}
```

**状态保持策略:**
- 使用 `keepAlive: true` 保持全局状态
- 默认自动释放短期状态
- 数据库连接使用 keepAlive

## 数据模型

**Freezed 模型:**
```dart
@freezed
class SavedAccount with _$SavedAccount {
  const SavedAccount._();

  const factory SavedAccount({
    required String id,
    required String email,
    @Default('') String nickname,
    @Default(false) bool isDefault,
  }) = _SavedAccount;

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);
}
```

**模型规范:**
- 使用 `@Default()` 提供默认值
- 私有构造函数 `const SavedAccount._()`
- 添加 `fromJson` 工厂构造函数
- 使用 `part` 语句链接生成文件

## 注释规范

**文档注释:**
- 使用 `///` 格式
- 类和方法必须有文档注释
- 参数说明: `[param] 说明`

**代码内注释:**
- 使用 `//` 格式
- 解释 "为什么" 而非 "做什么"
- 复杂算法添加步骤说明

**禁止:**
- 版本号后缀命名: `_v2`, `_v3`
- 语义不明的缩写
- 魔法数字（使用常量替代）

## 资源引用

**国际化:**
- 使用 `context.l10n.keyName` 访问
- 键名使用小驼峰
- 支持中文和英文

**图片资源:**
- 使用 `assets/images/`, `assets/icons/`
- 在 `pubspec.yaml` 中声明

---

*规范分析: 2026-02-28*
