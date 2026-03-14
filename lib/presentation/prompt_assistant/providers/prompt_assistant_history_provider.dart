import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptHistoryStack {
  final List<String> undoStack;
  final List<String> redoStack;
  final List<String> history;

  const PromptHistoryStack({
    this.undoStack = const [],
    this.redoStack = const [],
    this.history = const [],
  });

  PromptHistoryStack copyWith({
    List<String>? undoStack,
    List<String>? redoStack,
    List<String>? history,
  }) {
    return PromptHistoryStack(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      history: history ?? this.history,
    );
  }

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

final promptAssistantHistoryProvider = StateNotifierProvider<
    PromptAssistantHistoryNotifier, Map<String, PromptHistoryStack>>(
  (ref) => PromptAssistantHistoryNotifier(),
);

class PromptAssistantHistoryNotifier
    extends StateNotifier<Map<String, PromptHistoryStack>> {
  PromptAssistantHistoryNotifier() : super(const {});

  PromptHistoryStack stackOf(String sessionId) {
    return state[sessionId] ?? const PromptHistoryStack();
  }

  void _put(String sessionId, PromptHistoryStack stack) {
    state = {...state, sessionId: stack};
  }

  void push(String sessionId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final stack = stackOf(sessionId);
    final undo = [...stack.undoStack];
    if (undo.isNotEmpty && undo.last == text) return;
    undo.add(text);
    if (undo.length > 50) {
      undo.removeAt(0);
    }

    final history = [...stack.history];
    if (history.isEmpty || history.last != text) {
      history.add(text);
      if (history.length > 50) {
        history.removeAt(0);
      }
    }

    _put(
      sessionId,
      stack.copyWith(
        undoStack: undo,
        redoStack: const [],
        history: history,
      ),
    );
  }

  String? undo(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.undoStack.isEmpty) return null;
    final undo = [...stack.undoStack];
    final redo = [...stack.redoStack];

    if (undo.isNotEmpty && undo.last == currentText) {
      redo.add(undo.removeLast());
    } else {
      redo.add(currentText);
    }

    if (undo.isEmpty) {
      _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
      return null;
    }

    final value = undo.removeLast();
    _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
    return value;
  }

  String? redo(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.redoStack.isEmpty) return null;
    final undo = [...stack.undoStack, currentText];
    final redo = [...stack.redoStack];
    final value = redo.removeLast();
    _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
    return value;
  }
}
