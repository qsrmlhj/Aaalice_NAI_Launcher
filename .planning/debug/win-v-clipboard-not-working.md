---
status: resolved
trigger: "win-v-clipboard-not-working"
created: 2026-02-28T00:00:00Z
updated: 2026-02-28T00:30:00Z
---

## Current Focus

hypothesis: autocomplete_wrapper.dart 中的 Focus 组件已修复，现在只在补全菜单显示时才注册 onKeyEvent
test: 验证修复是否解决了 Win+V 问题，同时检查其他可能拦截键盘事件的组件
expecting: Win+V 系统快捷键能够正常工作，同时自动补全功能不受影响
next_action: 检查其他组件是否有类似问题，并更新状态为 fixing

## Symptoms

expected: 在提示词输入框中按下 Win+V 应该弹出 Windows 剪贴板历史面板，选择项目后应该能粘贴到输入框
actual: 按下 Win+V 没有任何反应，剪贴板历史面板不弹出或无法粘贴
errors: 无明显错误，只是 Win+V 快捷键无效
reproduction:
1. 打开 T2I 生成界面
2. 点击提示词输入框
3. 按下 Win+V (Windows 剪贴板历史快捷键)
4. 没有任何反应，或者面板弹出但无法粘贴
started: Issue #46 报告于 2026-02-28

## Eliminated

## Evidence

- timestamp: 2026-02-28
  checked: unified_prompt_input.dart
  found: 使用 ThemedInput 包装，没有直接键盘事件处理
  implication: 问题不在 ThemedInput 本身

- timestamp: 2026-02-28
  checked: autocomplete_wrapper.dart (line 722-732)
  found: Focus widget 使用 onKeyEvent 处理键盘事件，_handleKeyEvent 返回 KeyEventResult.ignored 当补全菜单未显示时
  implication: 理论上应该让系统快捷键通过，但需要进一步确认

- timestamp: 2026-02-28
  checked: tag_view.dart (line 289-324)
  found: Focus widget 使用 onKeyEvent 处理键盘事件，返回 KeyEventResult.handled 拦截了 Ctrl+A、Delete、Ctrl+D、Escape
  implication: 这个组件处理标签视图的键盘事件，但不是提示词输入框的问题

- timestamp: 2026-02-28
  checked: desktop_layout.dart (line 733-737)
  found: GenerationControls 使用 ShortcutAwareWidget 包装整个控制区域，autofocus: true
  implication: ShortcutAwareWidget 使用 CallbackShortcuts + FocusScope，可能会拦截键盘事件

- timestamp: 2026-02-28
  checked: shortcut_aware_widget.dart (line 133-149)
  found: CallbackShortcuts 包装 FocusScope，当快捷键匹配时会拦截事件
  implication: CallbackShortcuts 可能会消耗所有匹配的键盘事件，但 Win+V 应该不匹配任何注册的快捷键

- timestamp: 2026-02-28
  checked: autocomplete_wrapper.dart (line 722-730)
  found: Focus widget 设置了 skipTraversal: true, canRequestFocus: false, 但仍然注册 onKeyEvent 回调
  implication: 即使 canRequestFocus: false，Focus widget 仍可能拦截键盘事件，影响系统快捷键传递

- timestamp: 2026-02-28
  checked: Flutter 文档和已知问题
  found: 当 Focus widget 注册 onKeyEvent 时，即使返回 KeyEventResult.ignored，也可能影响系统级快捷键的传递
  implication: 需要修改 Focus 组件配置，避免在不需要时拦截键盘事件

## Resolution

root_cause: autocomplete_wrapper.dart 中的 Focus 组件始终注册 onKeyEvent 回调，即使补全菜单未显示。这导致所有键盘事件都经过该回调处理，虽然返回 KeyEventResult.ignored，但仍可能干扰系统级快捷键（如 Win+V）的传递。

fix: 修改 Focus 组件，只在补全菜单显示时（_showSuggestions 为 true）才注册 onKeyEvent 回调。当补全菜单隐藏时，onKeyEvent 设为 null，让键盘事件直接传递给底层组件和操作系统。

verification: 待验证 - 需要测试 Win+V 在提示词输入框中是否能正常弹出剪贴板历史面板

files_changed:
  - lib/presentation/widgets/autocomplete/autocomplete_wrapper.dart
