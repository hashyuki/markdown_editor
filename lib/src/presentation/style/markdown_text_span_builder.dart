import 'package:flutter/material.dart';

import '../../domain/model/line_syntax.dart';
import '../../domain/service/line_syntax_parser.dart';
import 'line_style_resolver.dart';
import 'line_text_renderer.dart';

class MarkdownTextSpanBuilder {
  const MarkdownTextSpanBuilder({
    required this.text,
    required this.value,
    required this.baseStyle,
    required this.paragraphStyle,
    required this.headingStyles,
    required this.parser,
    required this.lineTextRenderer,
    required this.lineStyleResolver,
    required this.withComposing,
  });

  final String text;
  final TextEditingValue value;
  final TextStyle baseStyle;
  final TextStyle? paragraphStyle;
  final Map<int, TextStyle> headingStyles;
  final LineSyntaxParser parser;
  final LineTextRenderer lineTextRenderer;
  final LineStyleResolver lineStyleResolver;
  final bool withComposing;

  TextSpan build() {
    final effectiveBaseStyle = baseStyle.merge(paragraphStyle);
    final children = <InlineSpan>[];
    final composingRange = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    final orderedLevels = <_OrderedVisualLevel>[];
    var lineStart = 0;

    for (var offset = 0; offset <= text.length; offset++) {
      final isLineEnd = offset == text.length || text.codeUnitAt(offset) == 10;
      if (!isLineEnd) {
        continue;
      }

      final lineEnd = offset;
      final lineText = text.substring(lineStart, lineEnd);
      final syntax = parser.parse(lineText);
      final orderedDisplayNumber = _nextOrderedDisplayNumber(
        syntax: syntax,
        levels: orderedLevels,
      );
      final renderedLineText = lineTextRenderer.render(
        lineText: lineText,
        syntax: syntax,
        orderedDisplayNumber: orderedDisplayNumber,
      );
      final resolvedLineStyle = lineStyleResolver.resolve(
        paragraphStyle: effectiveBaseStyle,
        syntax: syntax,
        headingStyles: headingStyles,
      );
      children.add(
        _buildComposingTextSpan(
          text: renderedLineText,
          style: resolvedLineStyle,
          segmentStart: lineStart,
          segmentEnd: lineEnd,
          composingRange: composingRange,
        ),
      );

      if (offset < text.length) {
        children.add(
          _buildComposingTextSpan(
            text: '\n',
            style: effectiveBaseStyle,
            segmentStart: offset,
            segmentEnd: offset + 1,
            composingRange: composingRange,
          ),
        );
        lineStart = offset + 1;
      }
    }

    return TextSpan(style: effectiveBaseStyle, children: children);
  }

  int? _nextOrderedDisplayNumber({
    required LineSyntax syntax,
    required List<_OrderedVisualLevel> levels,
  }) {
    final list = syntax.list;
    if (list == null || list.type != ListType.ordered) {
      levels.clear();
      return null;
    }

    levels.removeWhere((level) => level.indent > list.indent);
    _OrderedVisualLevel? currentLevel;
    for (final level in levels) {
      if (level.indent == list.indent) {
        currentLevel = level;
        break;
      }
    }
    if (currentLevel == null) {
      currentLevel = _OrderedVisualLevel(indent: list.indent);
      levels.add(currentLevel);
    }

    final number = currentLevel.nextNumber;
    currentLevel.nextNumber += 1;
    return number;
  }

  TextSpan _buildComposingTextSpan({
    required String text,
    required TextStyle style,
    required int segmentStart,
    required int segmentEnd,
    required TextRange? composingRange,
  }) {
    if (text.isEmpty || composingRange == null) {
      return TextSpan(text: text, style: style);
    }
    final overlapStart = segmentStart > composingRange.start
        ? segmentStart
        : composingRange.start;
    final overlapEnd = segmentEnd < composingRange.end
        ? segmentEnd
        : composingRange.end;
    if (overlapStart >= overlapEnd) {
      return TextSpan(text: text, style: style);
    }

    final localOverlapStart = overlapStart - segmentStart;
    final localOverlapEnd = overlapEnd - segmentStart;
    final mergedDecoration = TextDecoration.combine([
      if (style.decoration != null) style.decoration!,
      TextDecoration.underline,
    ]);
    final composingStyle = style.copyWith(decoration: mergedDecoration);
    final children = <InlineSpan>[];

    if (localOverlapStart > 0) {
      children.add(
        TextSpan(text: text.substring(0, localOverlapStart), style: style),
      );
    }
    children.add(
      TextSpan(
        text: text.substring(localOverlapStart, localOverlapEnd),
        style: composingStyle,
      ),
    );
    if (localOverlapEnd < text.length) {
      children.add(
        TextSpan(text: text.substring(localOverlapEnd), style: style),
      );
    }

    return TextSpan(style: style, children: children);
  }
}

class _OrderedVisualLevel {
  _OrderedVisualLevel({required this.indent});

  final int indent;
  int nextNumber = 1;
}
