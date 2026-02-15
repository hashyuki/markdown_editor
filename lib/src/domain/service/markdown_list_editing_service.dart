import '../model/line_syntax.dart';
import 'line_syntax_parser.dart';
import 'line_text_range.dart';
import 'dart:math' as math;

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

  static const int _indentSize = 2;

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

  EditorTextSnapshot applyTabIndentation({
    required EditorTextSnapshot value,
    required bool outdent,
  }) {
    if (!value.isSelectionValid) {
      return value;
    }

    final lineStarts = _selectedLineStarts(
      text: value.text,
      baseOffset: value.baseOffset,
      extentOffset: value.extentOffset,
    );
    var snapshot = value;
    var cumulativeDelta = 0;

    for (final originalLineStart in lineStarts) {
      final currentLineStart = originalLineStart + cumulativeDelta;
      final result = _applyTabIndentationToLine(
        snapshot: snapshot,
        lineStart: currentLineStart,
        outdent: outdent,
      );
      snapshot = result.snapshot;
      cumulativeDelta += result.delta;
    }

    return snapshot;
  }

  ({EditorTextSnapshot snapshot, int delta}) _applyTabIndentationToLine({
    required EditorTextSnapshot snapshot,
    required int lineStart,
    required bool outdent,
  }) {
    if (lineStart < 0 || lineStart > snapshot.text.length) {
      return (snapshot: snapshot, delta: 0);
    }
    final lineRange = lineTextRangeForOffset(snapshot.text, lineStart);
    final lineText = snapshot.text.substring(lineRange.start, lineRange.end);
    final list = _parser.parse(lineText).list;
    if (list == null) {
      return (snapshot: snapshot, delta: 0);
    }

    final oldIndent = list.indent;
    final indentStep = _indentStepForList(list);
    final newIndent = outdent
        ? (oldIndent - indentStep).clamp(0, oldIndent)
        : oldIndent + indentStep;
    if (newIndent == oldIndent) {
      return (snapshot: snapshot, delta: 0);
    }

    final oldPrefix = _listPrefix(oldIndent, list.marker, list.number);
    final updatedNumber = _updatedNumberForTab(list: list);
    final newPrefix = _listPrefix(newIndent, list.marker, updatedNumber);
    final content = lineText.substring(oldPrefix.length);
    final updatedLineText = '$newPrefix$content';
    final updatedText = snapshot.text.replaceRange(
      lineRange.start,
      lineRange.end,
      updatedLineText,
    );
    final totalDelta = updatedLineText.length - lineText.length;
    final prefixDelta = newPrefix.length - oldPrefix.length;

    int adjustOffset(int original) {
      if (original < lineRange.start) {
        return original;
      }
      if (original > lineRange.end) {
        return original + totalDelta;
      }
      final localOffset = original - lineRange.start;
      final shiftedLocal = localOffset <= oldPrefix.length
          ? (localOffset + prefixDelta).clamp(0, newPrefix.length)
          : localOffset + totalDelta;
      final shifted = lineRange.start + shiftedLocal;
      final lineEnd = lineRange.start + updatedLineText.length;
      return shifted.clamp(lineRange.start, lineEnd);
    }

    return (
      snapshot: EditorTextSnapshot(
        text: updatedText,
        baseOffset: adjustOffset(snapshot.baseOffset),
        extentOffset: adjustOffset(snapshot.extentOffset),
      ),
      delta: totalDelta,
    );
  }

  List<int> _selectedLineStarts({
    required String text,
    required int baseOffset,
    required int extentOffset,
  }) {
    final start = math.min(baseOffset, extentOffset).clamp(0, text.length);
    final end = math.max(baseOffset, extentOffset).clamp(0, text.length);
    final anchor = end > start ? end - 1 : end;
    final firstLineStart = lineTextRangeForOffset(text, start).start;
    final lastLineStart = lineTextRangeForOffset(text, anchor).start;
    final starts = <int>[];

    var cursor = firstLineStart;
    while (true) {
      starts.add(cursor);
      if (cursor >= lastLineStart) {
        break;
      }
      final newlineIndex = text.indexOf('\n', cursor);
      if (newlineIndex == -1) {
        break;
      }
      cursor = newlineIndex + 1;
    }
    return starts;
  }

  int _indentStepForList(ListSyntax list) {
    if (list.type == ListType.ordered) {
      return list.number!.toString().length + 2;
    }
    return _indentSize;
  }

  int? _updatedNumberForTab({required ListSyntax list}) {
    if (list.type != ListType.ordered) {
      return list.number;
    }
    return 1;
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
      if (list.indent > 0) {
        final parentIndent = (list.indent - _indentStepForList(list)).clamp(
          0,
          list.indent,
        );
        final parentPrefix = _listPrefix(
          parentIndent,
          list.marker,
          _updatedNumberForTab(list: list),
        );
        var replaceEnd = lineRange.end;
        if (replaceEnd < newValue.text.length &&
            newValue.text.substring(replaceEnd, replaceEnd + 1) == '\n') {
          replaceEnd += 1;
        }
        final adjustedText = newValue.text.replaceRange(
          lineRange.start,
          replaceEnd,
          parentPrefix,
        );
        final adjustedOffset = lineRange.start + parentPrefix.length;
        return EditorTextSnapshot(
          text: adjustedText,
          baseOffset: adjustedOffset,
          extentOffset: adjustedOffset,
        );
      }

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
      return '${indentation}1. ';
    }
    return '$indentation${marker!} ';
  }
}
