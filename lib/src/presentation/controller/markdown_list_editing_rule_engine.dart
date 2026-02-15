import '../../domain/model/text_edit_state.dart';
import '../../domain/service/markdown_list_editing_service.dart';

class MarkdownListEditingRuleEngine {
  MarkdownListEditingRuleEngine({required MarkdownListEditingService service})
    : _service = service;

  final MarkdownListEditingService _service;

  TextEditState apply({
    required TextEditState oldValue,
    required TextEditState newValue,
  }) {
    if (!oldValue.isSelectionValid ||
        !newValue.isSelectionValid ||
        !oldValue.isCollapsed ||
        !newValue.isCollapsed) {
      return newValue;
    }

    if (_isSingleNewlineInsertion(oldValue: oldValue, newValue: newValue)) {
      final adjusted = _service.applyEnter(value: oldValue);
      return adjusted == oldValue ? newValue : adjusted;
    }

    if (_isSingleBackspaceDeletion(oldValue: oldValue, newValue: newValue)) {
      final adjusted = _service.applyBackspace(value: oldValue);
      return adjusted == oldValue ? newValue : adjusted;
    }

    return newValue;
  }

  bool _isSingleNewlineInsertion({
    required TextEditState oldValue,
    required TextEditState newValue,
  }) {
    if (newValue.text.length != oldValue.text.length + 1) {
      return false;
    }

    final insertionOffset = oldValue.selectionEnd;
    if (insertionOffset < 0 || insertionOffset > oldValue.text.length) {
      return false;
    }
    if (newValue.selectionEnd != insertionOffset + 1) {
      return false;
    }
    if (newValue.text.substring(0, insertionOffset) !=
        oldValue.text.substring(0, insertionOffset)) {
      return false;
    }
    if (newValue.text.substring(insertionOffset, insertionOffset + 1) != '\n') {
      return false;
    }
    if (newValue.text.substring(insertionOffset + 1) !=
        oldValue.text.substring(insertionOffset)) {
      return false;
    }
    return true;
  }

  bool _isSingleBackspaceDeletion({
    required TextEditState oldValue,
    required TextEditState newValue,
  }) {
    if (newValue.text.length + 1 != oldValue.text.length) {
      return false;
    }

    final oldOffset = oldValue.selectionEnd;
    if (oldOffset <= 0) {
      return false;
    }
    if (newValue.selectionEnd != oldOffset - 1) {
      return false;
    }
    if (oldValue.text.substring(0, oldOffset - 1) !=
        newValue.text.substring(0, oldOffset - 1)) {
      return false;
    }
    if (oldValue.text.substring(oldOffset) !=
        newValue.text.substring(oldOffset - 1)) {
      return false;
    }
    return true;
  }
}
