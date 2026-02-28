# Phase 1: 词库分组视图 - Context

**Gathered:** 2025-02-28
**Status:** Ready for planning

## Phase Boundary

为词库页面添加按类别分组的视图模式，并设为默认视图。同时添加全局排序功能。

**Scope:**
- 修改视图切换为3状态（列表/网格/分组）
- 实现分组视图的吸顶类别标题
- 分组内使用卡片展示条目
- Toolbar 添加排序下拉菜单（全局生效）
- 分组视图设为默认

**Out of scope:**
- 新的排序算法（复用现有的 TagLibrarySortBy）
- 条目详情页修改
- 分类树修改

## Implementation Decisions

### 视图切换
- **样式**: 横排3按钮（列表 | 网格 | 分组）
- **位置**: Toolbar 右侧，保持现有位置
- **默认**: 分组视图

### 分组视图
- **内容样式**: 使用现有的 EntryCard 组件
- **标题样式**: 吸顶标题（Sticky Header），滚动时类别名称固定在顶部
- **类别排序**: 跟随全局排序设置

### 排序功能
- **位置**: Toolbar，视图切换按钮左边
- **范围**: 全局生效，所有视图共享排序设置
- **选项**: 时间、字母（名称）、使用频率
- **UI**: 下拉菜单样式

### 技术实现
- 修改 `TagLibraryViewMode` 枚举添加 `grouped`
- 修改默认 `viewMode` 为 `grouped`
- 使用 `SliverStickyHeader` 或类似组件实现吸顶效果
- Toolbar 添加 `DropdownButton` 或自定义下拉菜单

## Existing Code Insights

### Reusable Assets
- `EntryCard` 组件 — 分组视图中复用
- `TagLibraryViewMode` 枚举 — 添加 `grouped` 值
- `TagLibrarySortBy` 枚举 — 已有排序选项
- `_ViewModeButton` — 参考样式

### Established Patterns
- Riverpod 状态管理 — `tagLibraryPageNotifierProvider`
- Toolbar 在 `TagLibraryToolbar` 中构建
- 视图渲染在 `TagLibraryPageScreen` 中根据 `viewMode` 切换

### Integration Points
- Toolbar: `_buildViewModeToggle()` 方法需要修改
- Page Screen: 根据 `viewMode` 渲染不同视图，需要添加分组视图分支
- State: 默认 `viewMode` 从 `card` 改为 `grouped`

## Specific Ideas

- 吸顶标题参考 iOS 通讯录或微信联系人列表效果
- 排序下拉菜单使用 Material Design 风格
- 分组视图中空类别可以显示占位提示

## Deferred Ideas

- 拖拽排序类别（未来版本考虑）
- 折叠/展开类别（如果类别很多时有用）

---

*Phase: 01-词库分组视图*
*Context gathered: 2025-02-28*
