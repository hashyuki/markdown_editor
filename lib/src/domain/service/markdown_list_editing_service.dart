import 'line_syntax_parser.dart';
import 'line_text_range.dart';

class EditorTextSnapshot {
  const EditorTextSnapshot({
    required this.text,
    required this.baseOffset,
    required this.extentOffset,
  });

  final String text;
  final int baseOffset;
  final int extentOffset;

  bool get isSelectionValid =>
      baseOffset >= 0 &&
      extentOffset >= 0 &&
      baseOffset <= text.length &&
      extentOffset <= text.length;

  bool get isCollapsed => baseOffset == extentOffset;

  EditorTextSnapshot copyWith({
    String? text,
    int? baseOffset,
    int? extentOffset,
  }) {
    return EditorTextSnapshot(
      text: text ?? this.text,
      baseOffset: baseOffset ?? this.baseOffset,
      extentOffset: extentOffset ?? this.extentOffset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is EditorTextSnapshot &&
        text == other.text &&
        baseOffset == other.baseOffset &&
        extentOffset == other.extentOffset;
  }

  @override
  int get hashCode => Object.hash(text, baseOffset, extentOffset);
}

class MarkdownListEditingService {
  MarkdownListEditingService({required LineSyntaxParser parser})
    : _parser = parser;

  LineSyntaxParser _parser;

  void updateParser(LineSyntaxParser parser) {
    _parser = parser;
  }

  EditorTextSnapshot applyRules({
    required EditorTextSnapshot oldValue,
    required EditorTextSnapshot newValue,
  }) {
    if (!oldValue.isSelectionValid ||
        !newValue.isSelectionValid ||
        !oldValue.isCollapsed ||
        !newValue.isCollapsed) {
      return newValue;
    }

    final enterAdjusted = _applyEnterRule(
      oldValue: oldValue,
      newValue: newValue,
    );
    if (enterAdjusted != null) {
      return enterAdjusted;
    }

    final backspaceAdjusted = _applyBackspaceRule(
      oldValue: oldValue,
      newValue: newValue,
    );
    if (backspaceAdjusted != null) {
      return backspaceAdjusted;
    }

    return newValue;
  }

  EditorTextSnapshot? _applyEnterRule({
    required EditorTextSnapshot oldValue,
    required EditorTextSnapshot newValue,
  }) {
    if (newValue.text.length != oldValue.text.length + 1) {
      return null;
    }

    final insertionOffset = oldValue.extentOffset;
    if (insertionOffset < 0 || insertionOffset > oldValue.text.length) {
      return null;
    }
    if (newValue.extentOffset != insertionOffset + 1) {
      return null;
    }

    if (newValue.text.substring(0, insertionOffset) !=
        oldValue.text.substring(0, insertionOffset)) {
      return null;
    }
    if (newValue.text.substring(insertionOffset, insertionOffset + 1) != '\n') {
      return null;
    }
    if (newValue.text.substring(insertionOffset + 1) !=
        oldValue.text.substring(insertionOffset)) {
      return null;
    }

    final lineRange = lineTextRangeForOffset(oldValue.text, insertionOffset);
    final lineText = oldValue.text.substring(lineRange.start, lineRange.end);
    final list = _parser.parse(lineText).list;
    if (list == null) {
      return null;
    }

    final listPrefix = _listPrefix(list.indent, list.marker, list.number);
    final contentText = lineText.length > listPrefix.length
        ? lineText.substring(listPrefix.length)
        : '';

    if (contentText.trim().isEmpty) {
      final adjustedText = newValue.text.replaceRange(
        lineRange.start,
        lineRange.end,
        '',
      );
      final removedLength = lineRange.end - lineRange.start;
      final adjustedOffset = newValue.extentOffset - removedLength;
      return EditorTextSnapshot(
        text: adjustedText,
        baseOffset: adjustedOffset,
        extentOffset: adjustedOffset,
      );
    }

    final nextPrefix = _nextListPrefix(list.indent, list.marker, list.number);
    final adjustedText = newValue.text.replaceRange(
      insertionOffset + 1,
      insertionOffset + 1,
      nextPrefix,
    );
    final adjustedOffset = newValue.extentOffset + nextPrefix.length;
    return EditorTextSnapshot(
      text: adjustedText,
      baseOffset: adjustedOffset,
      extentOffset: adjustedOffset,
    );
  }

  EditorTextSnapshot? _applyBackspaceRule({
    required EditorTextSnapshot oldValue,
    required EditorTextSnapshot newValue,
  }) {
    if (newValue.text.length + 1 != oldValue.text.length) {
      return null;
    }

    final oldOffset = oldValue.extentOffset;
    if (oldOffset <= 0) {
      return null;
    }
    if (newValue.extentOffset != oldOffset - 1) {
      return null;
    }
    if (oldValue.text.substring(0, oldOffset - 1) !=
        newValue.text.substring(0, oldOffset - 1)) {
      return null;
    }
    if (oldValue.text.substring(oldOffset) !=
        newValue.text.substring(oldOffset - 1)) {
      return null;
    }

    final lineRange = lineTextRangeForOffset(oldValue.text, oldOffset);
    if (oldOffset != lineRange.end) {
      return null;
    }

    final lineText = oldValue.text.substring(lineRange.start, lineRange.end);
    final list = _parser.parse(lineText).list;
    if (list == null) {
      return null;
    }

    final listPrefix = _listPrefix(list.indent, list.marker, list.number);
    if (lineText != listPrefix) {
      return null;
    }

    final adjustedText = oldValue.text.replaceRange(
      lineRange.start,
      lineRange.end,
      '',
    );
    return EditorTextSnapshot(
      text: adjustedText,
      baseOffset: lineRange.start,
      extentOffset: lineRange.start,
    );
  }

  String _listPrefix(int indent, String? marker, int? number) {
    final indentation = ' ' * indent;
    if (number != null) {
      return '$indentation$number. ';
    }
    return '$indentation${marker!} ';
  }

  String _nextListPrefix(int indent, String? marker, int? number) {
    final indentation = ' ' * indent;
    if (number != null) {
      return '$indentation${number + 1}. ';
    }
    return '$indentation${marker!} ';
  }
}
