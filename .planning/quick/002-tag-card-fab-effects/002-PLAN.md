# Quick Task 002: 词库卡片悬浮按钮动效和提示

## 任务描述
为 EntryCard 的悬浮操作按钮添加悬浮动效和 Tooltip 提示。

## 当前状态分析
- EntryCard 位于 `lib/presentation/screens/tag_library_page/widgets/entry_card.dart`
- 悬浮按钮使用内部类 `_ActionIcon` 实现
- 目前按钮只有基础样式，没有悬浮动效和 Tooltip

## 修改计划

### 任务 1: 修改 _ActionIcon 添加悬浮动效和 Tooltip

**文件**: `lib/presentation/screens/tag_library_page/widgets/entry_card.dart`

**修改内容**:
1. 将 `_ActionIcon` 从 `StatelessWidget` 改为 `StatefulWidget`
2. 添加悬浮状态管理 (`_isHovering`)
3. 添加 `Tooltip` 包装，显示按钮功能提示
4. 添加悬浮动效:
   - 缩放效果 (scale 1.0 → 1.15)
   - 背景色变化
   - 阴影效果
5. 支持自定义 tooltip 文本

**按钮对应的 Tooltip 文本**:
- 删除: `context.l10n.common_delete`
- 编辑: `context.l10n.common_edit`
- 收藏/取消收藏: 根据状态显示
- 复制: `context.l10n.common_copy`

**验证方式**:
- 悬停在按钮上时显示 Tooltip
- 按钮有缩放和阴影动效
- 代码分析无错误

## 执行步骤
1. 修改 `_ActionIcon` 类，添加动效和 Tooltip
2. 更新调用处，传入 tooltip 参数
3. 运行代码分析验证
