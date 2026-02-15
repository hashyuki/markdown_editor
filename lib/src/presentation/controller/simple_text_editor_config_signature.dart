import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/service/line_syntax_parser.dart';
import '../style/line_style_resolver.dart';

class SimpleTextEditorConfigSignature {
  const SimpleTextEditorConfigSignature({
    required this.paragraphStyle,
    required this.headingStyleEntries,
    required this.lineSyntaxParser,
    required this.lineStyleResolver,
  });

  factory SimpleTextEditorConfigSignature.fromValues({
    required TextStyle? paragraphStyle,
    required Map<int, TextStyle> headingStyles,
    required LineSyntaxParser lineSyntaxParser,
    required LineStyleResolver lineStyleResolver,
  }) {
    final entries = headingStyles.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return SimpleTextEditorConfigSignature(
      paragraphStyle: paragraphStyle,
      headingStyleEntries: entries
          .map(
            (entry) => HeadingStyleEntrySignature(
              level: entry.key,
              style: entry.value,
            ),
          )
          .toList(growable: false),
      lineSyntaxParser: lineSyntaxParser,
      lineStyleResolver: lineStyleResolver,
    );
  }

  final TextStyle? paragraphStyle;
  final List<HeadingStyleEntrySignature> headingStyleEntries;
  final LineSyntaxParser lineSyntaxParser;
  final LineStyleResolver lineStyleResolver;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SimpleTextEditorConfigSignature &&
        paragraphStyle == other.paragraphStyle &&
        lineSyntaxParser == other.lineSyntaxParser &&
        lineStyleResolver == other.lineStyleResolver &&
        listEquals(headingStyleEntries, other.headingStyleEntries);
  }

  @override
  int get hashCode => Object.hash(
    paragraphStyle,
    lineSyntaxParser,
    lineStyleResolver,
    Object.hashAll(headingStyleEntries),
  );
}

class HeadingStyleEntrySignature {
  const HeadingStyleEntrySignature({required this.level, required this.style});

  final int level;
  final TextStyle style;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HeadingStyleEntrySignature &&
        level == other.level &&
        style == other.style;
  }

  @override
  int get hashCode => Object.hash(level, style);
}
