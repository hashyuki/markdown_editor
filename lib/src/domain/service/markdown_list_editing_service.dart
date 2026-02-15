import 'dart:math' as math;

import '../model/line_syntax.dart';
import '../model/text_edit_state.dart';
import 'line_syntax_parser.dart';
import 'line_text_range.dart';

class MarkdownListEditingService {
  MarkdownListEditingService({required LineSyntaxParser parser})
    : _parser = parser;

  static const int _indentSize = 2;

  final LineSyntaxParser _parser;

  TextEditState applyEnter({required TextEditState value}) {
    return _applyEnterRule(value: value) ?? value;
  }

  TextEditState applyBackspace({required TextEditState value}) {
    return _applyBackspaceRule(value: value) ?? value;
  }

  TextEditState applyTabIndentation({
    required TextEditState value,
    required bool outdent,
  }) {
    if (!value.isSelectionValid) {
      return value;
    }

    final lineStarts = _selectedLineStarts(
      text: value.text,
      selectionStart: value.selectionStart,
      selectionEnd: value.selectionEnd,
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

  ({TextEditState snapshot, int delta}) _applyTabIndentationToLine({
    required TextEditState snapshot,
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
        ? math.max(0, oldIndent - indentStep)
        : oldIndent + indentStep;
    if (newIndent == oldIndent) {
      return (snapshot: snapshot, delta: 0);
    }

    final oldPrefix = _listPrefix(oldIndent, list.marker, list.number);
    final updatedNumber = _normalizedOrderedNumber(list: list);
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
      snapshot: TextEditState(
        text: updatedText,
        selectionStart: adjustOffset(snapshot.selectionStart),
        selectionEnd: adjustOffset(snapshot.selectionEnd),
      ),
      delta: totalDelta,
    );
  }

  List<int> _selectedLineStarts({
    required String text,
    required int selectionStart,
    required int selectionEnd,
  }) {
    final start = math.min(selectionStart, selectionEnd).clamp(0, text.length);
    final end = math.max(selectionStart, selectionEnd).clamp(0, text.length);
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

  int? _normalizedOrderedNumber({required ListSyntax list}) {
    if (list.type != ListType.ordered) {
      return list.number;
    }
    return 1;
  }

  TextEditState? _applyEnterRule({required TextEditState value}) {
    if (!value.isSelectionValid || !value.isCollapsed) {
      return null;
    }
    final insertionOffset = value.selectionEnd;
    if (insertionOffset < 0 || insertionOffset > value.text.length) {
      return null;
    }

    final lineRange = lineTextRangeForOffset(value.text, insertionOffset);
    final lineText = value.text.substring(lineRange.start, lineRange.end);
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
        final parentIndent = math.max(
          0,
          list.indent - _indentStepForList(list),
        );
        final parentPrefix = _listPrefix(
          parentIndent,
          list.marker,
          _normalizedOrderedNumber(list: list),
        );
        final adjustedText = value.text.replaceRange(
          lineRange.start,
          lineRange.end,
          parentPrefix,
        );
        final adjustedOffset = lineRange.start + parentPrefix.length;
        return TextEditState(
          text: adjustedText,
          selectionStart: adjustedOffset,
          selectionEnd: adjustedOffset,
        );
      }

      final removedPrefixText = value.text.replaceRange(
        lineRange.start,
        lineRange.end,
        '',
      );
      final adjustedOffsetAfterRemoval =
          insertionOffset - (lineRange.end - lineRange.start);
      final adjustedText = removedPrefixText.replaceRange(
        adjustedOffsetAfterRemoval,
        adjustedOffsetAfterRemoval,
        '\n',
      );
      final adjustedOffset = adjustedOffsetAfterRemoval + 1;
      return TextEditState(
        text: adjustedText,
        selectionStart: adjustedOffset,
        selectionEnd: adjustedOffset,
      );
    }

    final nextPrefix = _nextListPrefix(list.indent, list.marker, list.number);
    final adjustedText = value.text.replaceRange(
      insertionOffset,
      insertionOffset,
      '\n$nextPrefix',
    );
    final adjustedOffset = insertionOffset + 1 + nextPrefix.length;
    return TextEditState(
      text: adjustedText,
      selectionStart: adjustedOffset,
      selectionEnd: adjustedOffset,
    );
  }

  TextEditState? _applyBackspaceRule({required TextEditState value}) {
    if (!value.isSelectionValid || !value.isCollapsed) {
      return null;
    }

    final oldOffset = value.selectionEnd;
    if (oldOffset <= 0) {
      return null;
    }

    final lineRange = lineTextRangeForOffset(value.text, oldOffset);
    if (oldOffset != lineRange.end) {
      return null;
    }

    final lineText = value.text.substring(lineRange.start, lineRange.end);
    final list = _parser.parse(lineText).list;
    if (list == null) {
      return null;
    }

    final listPrefix = _listPrefix(list.indent, list.marker, list.number);
    if (lineText != listPrefix) {
      return null;
    }

    final adjustedText = value.text.replaceRange(
      lineRange.start,
      lineRange.end,
      '',
    );
    return TextEditState(
      text: adjustedText,
      selectionStart: lineRange.start,
      selectionEnd: lineRange.start,
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
