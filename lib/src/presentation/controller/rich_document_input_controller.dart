import 'package:flutter/services.dart';

import '../../application/use_case/edit_rich_document_use_case.dart';
import '../../domain/model/rich_document_selection.dart';

class RichDocumentInputController {
  const RichDocumentInputController({
    this.editUseCase = const EditRichDocumentUseCase(),
  });

  final EditRichDocumentUseCase editUseCase;

  RichDocumentEditorState normalize(RichDocumentEditorState state) {
    return editUseCase.normalize(state);
  }

  RichDocumentEditorState collapseSelection(
    RichDocumentEditorState state,
    RichTextPosition position,
  ) {
    return normalize(
      state.copyWith(
        selection: RichSelection.collapsed(position),
        preferredColumn: position.offset,
      ),
    );
  }

  RichDocumentEditorState selectRange(
    RichDocumentEditorState state, {
    required RichTextPosition base,
    required RichTextPosition extent,
    int? preferredColumn,
  }) {
    return normalize(
      state.copyWith(
        selection: RichSelection(base: base, extent: extent),
        preferredColumn: preferredColumn,
      ),
    );
  }

  String selectedPlainText(RichDocumentEditorState state) {
    return editUseCase.selectedPlainText(state);
  }

  RichDocumentEditorState pastePlainText(
    RichDocumentEditorState state,
    String text,
  ) {
    return editUseCase.pastePlainText(state, text);
  }

  RichDocumentEditorState deleteSelection(RichDocumentEditorState state) {
    return editUseCase.deleteSelection(state);
  }

  RichDocumentEditorState? handleKeyDown(
    RichDocumentEditorState state,
    KeyDownEvent event, {
    required bool enableEditing,
    required Set<LogicalKeyboardKey> pressedKeys,
    bool allowCharacterInput = true,
  }) {
    final shift = _containsAny(pressedKeys, _shiftKeys);
    final isShortcut = _containsAny(pressedKeys, _shortcutKeys);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      return editUseCase.moveLeft(state, expand: shift);
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return editUseCase.moveRight(state, expand: shift);
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return editUseCase.moveUp(state, expand: shift);
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return editUseCase.moveDown(state, expand: shift);
    }
    if (key == LogicalKeyboardKey.home) {
      return editUseCase.moveToLineStart(state, expand: shift);
    }
    if (key == LogicalKeyboardKey.end) {
      return editUseCase.moveToLineEnd(state, expand: shift);
    }
    if (isShortcut && key == LogicalKeyboardKey.keyA) {
      return editUseCase.selectAll(state);
    }

    if (!enableEditing) {
      return null;
    }

    if (key == LogicalKeyboardKey.tab) {
      return shift
          ? editUseCase.outdentListItem(state)
          : editUseCase.indentListItem(state);
    }
    if (key == LogicalKeyboardKey.backspace) {
      return editUseCase.backspace(state);
    }
    if (key == LogicalKeyboardKey.enter) {
      return editUseCase.insertNewLine(state);
    }

    final char = event.character;
    if (allowCharacterInput &&
        !isShortcut &&
        char != null &&
        char.isNotEmpty &&
        char != '\n') {
      return editUseCase.insertText(state, char);
    }

    return null;
  }

  bool _containsAny(
    Set<LogicalKeyboardKey> pressedKeys,
    Set<LogicalKeyboardKey> targetKeys,
  ) {
    for (final key in targetKeys) {
      if (pressedKeys.contains(key)) {
        return true;
      }
    }
    return false;
  }
}

final Set<LogicalKeyboardKey> _shiftKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
};

final Set<LogicalKeyboardKey> _shortcutKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
};
