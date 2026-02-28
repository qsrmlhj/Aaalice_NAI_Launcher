---
status: awaiting_human_verify
trigger: "类别数量显示在屏幕最右侧，没有紧挨着分类标题"
created: 2026-02-28T19:45:00+08:00
updated: 2026-02-28T19:46:00+08:00
---

## Current Focus

hypothesis: 标题 Text 被 Expanded 包裹，占据了所有剩余空间，导致数量标签被推到最右侧
test: 已修复 - 移除 Expanded 包装
effect: 标题现在只占据内容所需空间，数量标签会紧挨着标题显示
next_action: 等待用户验证修复效果

## Symptoms

expected: 类别数量标签（如 "1"）应该紧挨着分类标题（如 "角色"）显示
actual: 数量标签显示在屏幕很远的右侧，与标题之间有大量空白
timeline: 刚完成 Phase 01 的 UAT 测试时发现
reproduction: 打开词库页面，切换到分组视图，观察分类标题和数量标签的位置
errors: 无错误信息，纯 UI 布局问题

## Eliminated

## Evidence

- timestamp: 2026-02-28T19:45:00+08:00
  checked: lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart
  found: Row 中的标题 Text 被 Expanded 包裹（第35-45行），这导致标题占据所有剩余空间
  implication: Expanded 会强制子组件占据所有可用空间，将后续子组件推到边缘

## Resolution

root_cause: 标题 Text 使用了 Expanded 包裹，导致它占据了 Row 中的所有剩余空间，将数量标签推到了最右侧
fix: 移除 Expanded，让标题只占据其内容所需的空间
verification: 代码修复完成，等待用户验证
files_changed:
  - lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart
