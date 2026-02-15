import 'package:flutter/material.dart';

import '../../domain/service/line_syntax_parser.dart';

class SelectionHeadingTracker extends ValueNotifier<int?> {
  SelectionHeadingTracker({
    required TextEditingController controller,
    required LineSyntaxParser parser,
  }) : _controller = controller,
       _parser = parser,
       super(null) {
    _controller.addListener(_updateHeadingLevel);
    _updateHeadingLevel();
  }

  final TextEditingController _controller;
  LineSyntaxParser _parser;

  void updateParser(LineSyntaxParser parser) {
    _parser = parser;
    _updateHeadingLevel();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHeadingLevel);
    super.dispose();
  }

  void _updateHeadingLevel() {
    final nextHeadingLevel = _headingLevelForSelection(_controller.value);
    if (value == nextHeadingLevel) {
      return;
    }
    value = nextHeadingLevel;
  }

  int? _headingLevelForSelection(TextEditingValue value) {
    final selection = value.selection;
    final text = value.text;
    if (text.isEmpty || !selection.isValid) {
      return null;
    }

    final offset = selection.extentOffset.clamp(0, text.length);
    final lineRange = _lineRangeForOffset(text, offset);
    final lineText = text.substring(lineRange.start, lineRange.end);
    return _parser.parse(lineText).headingLevel;
  }

  _LineRange _lineRangeForOffset(String text, int offset) {
    final lineStart = offset == 0
        ? 0
        : (text.lastIndexOf('\n', offset - 1) + 1);
    final lineEnd = text.indexOf('\n', offset);
    return _LineRange(
      start: lineStart,
      end: lineEnd == -1 ? text.length : lineEnd,
    );
  }
}

class _LineRange {
  const _LineRange({required this.start, required this.end});

  final int start;
  final int end;
}
