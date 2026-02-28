---
phase: 4
plan: 4
wave: 4
subsystem: tag-library
tags: [thumbnail, ui, widget]
dependency_graph:
  requires: [PLAN-01, PLAN-03]
  provides: []
  affects: [EntryCard, EntryListItem, EntryPreviewOverlay]
tech_stack:
  added: []
  patterns: [ThumbnailDisplay reusable component]
key_files:
  created:
    - lib/presentation/widgets/common/thumbnail_display.dart
  modified:
    - lib/presentation/screens/tag_library_page/widgets/entry_card.dart
    - lib/presentation/screens/tag_library_page/widgets/entry_list_item.dart
    - lib/presentation/screens/tag_library_page/widgets/entry_selector_dialog.dart
    - lib/presentation/widgets/prompt/components/library_entry_menu_item.dart
    - lib/presentation/widgets/tag_library/tag_library_picker_dialog.dart
decisions:
  - 创建可复用的 ThumbnailDisplay 组件统一处理 offset/scale 变换
  - 使用 OverflowBox 允许图片超出容器边界以实现 offset 效果
  - 使用 clamp 限制值范围确保安全性
metrics:
  duration: 25
  completed_date: "2026-02-28"
---

# Phase 4 Plan 4: EntryCard 和悬浮预览集成

## 执行摘要

创建 ThumbnailDisplay 组件并集成到所有显示词库条目缩略图的位置，使 offset/scale 调整功能在所有地方生效。

## 完成的任务

| 任务 | 描述 | 提交 |
|------|------|------|
| Task 1 | 创建 ThumbnailDisplay 组件 | d21e06a9 |
| Task 2 | 修改 EntryCard 背景图显示 | 2693dbb6 |
| Task 3 | 修改悬浮预览显示 | 3e532226 |
| Task 4 | 处理边界情况 | 8d4d6cac, 1b56d2d7, d94ad42c, a09635b0 |
| Task 5 | 验证所有显示位置 | 6c8693d6, a20c453e |

## 组件设计

### ThumbnailDisplay

位置：`lib/presentation/widgets/common/thumbnail_display.dart`

功能：
- 支持 offsetX/offsetY 偏移 (-1.0 ~ 1.0)
- 支持 scale 缩放 (1.0 ~ 3.0)
- 自动 clamp 值范围
- 错误时显示占位图
- 使用 OverflowBox 允许图片超出容器

## 修改的文件

1. **entry_card.dart**
   - EntryCard 背景图使用 ThumbnailDisplay
   - 悬浮预览 (_EntryPreviewOverlay) 使用 ThumbnailDisplay
   - 拖拽反馈 UI 使用 ThumbnailDisplay

2. **entry_list_item.dart**
   - 列表项缩略图使用 ThumbnailDisplay
   - _buildThumbnail 方法使用 ThumbnailDisplay

3. **entry_selector_dialog.dart**
   - 选择对话框缩略图使用 ThumbnailDisplay

4. **library_entry_menu_item.dart**
   - 菜单项缩略图使用 ThumbnailDisplay

5. **tag_library_picker_dialog.dart**
   - 选择器对话框缩略图使用 ThumbnailDisplay

## 验证结果

- [x] ThumbnailDisplay 组件创建完成
- [x] EntryCard 背景图根据 offset/scale 正确显示
- [x] 悬浮预览根据 offset/scale 正确显示
- [x] 现有条目默认居中显示 (offset 0,0, scale 1.0)
- [x] 图片错误时显示占位符
- [x] 所有显示预览图的位置都已更新
- [x] flutter analyze 无错误

## 提交历史

```
d21e06a9 feat(tag-library): 创建 ThumbnailDisplay 组件支持 offset/scale 调整
2693dbb6 feat(tag-library): EntryCard 使用 ThumbnailDisplay 显示背景图
3e532226 feat(tag-library): 悬浮预览使用 ThumbnailDisplay 显示图片
8d4d6cac feat(tag-library): EntryListItem 使用 ThumbnailDisplay 显示缩略图
1b56d2d7 feat(tag-library): EntrySelectorDialog 使用 ThumbnailDisplay 显示缩略图
d94ad42c feat(tag-library): LibraryEntryMenuItem 使用 ThumbnailDisplay 显示缩略图
a09635b0 feat(tag-library): TagLibraryPickerDialog 使用 ThumbnailDisplay 显示缩略图
6c8693d6 feat(tag-library): 拖拽反馈UI使用 ThumbnailDisplay 显示缩略图
a20c453e refactor(tag-library): 移除未使用的 dart:io import
```

## 技术细节

### 变换计算

```dart
// 确保值在有效范围内
final effectiveOffsetX = offsetX.clamp(-1.0, 1.0);
final effectiveOffsetY = offsetY.clamp(-1.0, 1.0);
final effectiveScale = scale.clamp(1.0, 3.0);

// 应用变换
transform: Matrix4.identity()
  ..translate(
    effectiveOffsetX * (width ?? 0) / 2,
    effectiveOffsetY * (height ?? 0) / 2,
  )
  ..scale(effectiveScale),
```

### 向后兼容

- 默认 offsetX/Y = 0.0 (居中)
- 默认 scale = 1.0 (原始大小)
- 现有条目无需迁移

## Deviations from Plan

无偏差 - 计划执行完全符合预期。

## Self-Check

- [x] ThumbnailDisplay 组件存在
- [x] 所有修改的文件都已提交
- [x] 分析无错误
