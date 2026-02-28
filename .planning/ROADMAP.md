# NAI Launcher — Roadmap

## Milestone: v1.0 稳定版

---

## Phase 1: 词库分组视图
**Goal**: 实现按类别分组的词库视图，并设为默认

**Depends**: None

**Plans**:
1. **枚举和状态**: 修改 `TagLibraryViewMode` 添加 `grouped`，更新默认值为 `grouped`
2. **Toolbar 改造**: 将视图切换从 2 按钮改为 3 按钮（列表/网格/分组）
3. **分组渲染**: 实现按类别分组的列表渲染逻辑
4. **UI 优化**: 分组标题样式、分组内卡片布局

**Success Criteria**:
- [x] 3 状态视图切换正常工作
- [x] 分组视图正确按类别分组显示
- [x] 分组视图设为默认
- [x] 界面美观，交互流畅

---
