---
status: resolved
trigger: "T2I界面使用 Ctrl+Enter 快捷键跑图时，只有焦点不在文本框内才生效。焦点在文本框内输入的是换行，无法触发跑图。"
created: "2026-02-28T00:00:00Z"
updated: "2026-02-28T00:00:00Z"
---

## Current Focus

hypothesis: 将 CallbackShortcuts 替换为 Shortcuts + Actions + Focus 组合，让快捷键在整个子树中都能工作
test: 修改已在 ShortcutAwareWidget 中实现，需要验证
expecting: Ctrl+Enter 在文本框内也能触发跑图
next_action: 等待用户验证修复效果

## Symptoms

expected: 无论焦点是否在提示词文本框内，按下 Ctrl+Enter 都应该触发图像生成（跑图）
actual: 
- 焦点不在文本框内时：Ctrl+Enter 可以正常触发跑图
- 焦点在文本框内时：Ctrl+Enter 只会输入换行，不触发跑图
errors: 无明显错误，只是快捷键被文本框的换行行为拦截
reproduction:
1. 打开 T2I 生成界面
2. 点击提示词输入框，确保焦点在框内
3. 按下 Ctrl+Enter
4. 文本框内出现换行，没有触发跑图
started: Issue #46 报告于 2026-02-28

## Eliminated

## Evidence

- timestamp: 2026-02-28
  checked: 快捷键系统结构
  found: ShortcutAwareWidget 使用 CallbackShortcuts + FocusScope 包裹子组件
  implication: 快捷键系统本身设计正确，但 TextField 消费了 Enter 键事件

- timestamp: 2026-02-28
  checked: desktop_layout.dart 中的快捷键绑定
  found: generateImage 快捷键通过 ShortcutAwareWidget 注册，contextType 为 ShortcutContext.generation
  implication: 快捷键绑定正确，问题在于事件传递

- timestamp: 2026-02-28
  checked: unified_prompt_input.dart 和 themed_input.dart
  found: 使用标准 TextField，没有自定义键盘事件处理
  implication: TextField 默认会消费 Enter 键，需要特殊处理来放行 Ctrl+Enter

- timestamp: 2026-02-28
  checked: Flutter 快捷键系统工作原理
  found: TextField 消费键盘事件时不会冒泡给父级的 CallbackShortcuts
  implication: 需要使用 Focus widget 的 onKeyEvent 来拦截并放行特定组合键

## Resolution

root_cause: CallbackShortcuts 依赖焦点树分发事件，但 TextField 默认会消费 Enter 键事件（包括 Ctrl+Enter），导致事件不会冒泡给父级的 CallbackShortcuts。ShortcutAwareWidget 使用 CallbackShortcuts 包裹子组件，当焦点在 TextField 内时，Ctrl+Enter 被 TextField 消费用于插入换行，无法触发跑图快捷键。

fix: 将 ShortcutAwareWidget 中的 CallbackShortcuts 替换为 Shortcuts + Actions + Focus 组合。Shortcuts widget 使用 Intent/Action 模式，可以在整个子树中正确处理快捷键，即使子组件（如 TextField）获得焦点也能正常工作。Focus widget 设置 skipTraversal: true 确保它不参与焦点遍历，只作为快捷键的锚点。

verification: 等待用户验证

files_changed:
- lib/presentation/widgets/shortcuts/shortcut_aware_widget.dart: 将 CallbackShortcuts + FocusScope 替换为 Shortcuts + Actions + Focus，修复 TextField 内快捷键不工作的问题
