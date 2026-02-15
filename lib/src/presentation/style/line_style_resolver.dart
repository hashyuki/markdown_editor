import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;

import '../../domain/model/line_syntax.dart';

abstract interface class LineStyleResolver {
  const LineStyleResolver();

  TextStyle resolve({
    required TextStyle paragraphStyle,
    required LineSyntax syntax,
    required Map<int, TextStyle> headingStyles,
  });
}

class HeadingLineStyleResolver implements LineStyleResolver {
  const HeadingLineStyleResolver();

  @override
  TextStyle resolve({
    required TextStyle paragraphStyle,
    required LineSyntax syntax,
    required Map<int, TextStyle> headingStyles,
  }) {
    final headingLevel = syntax.headingLevel;
    final style = headingLevel == null
        ? paragraphStyle
        : paragraphStyle.merge(headingStyles[headingLevel]);

    final list = syntax.list;
    if (list == null || list.type != ListType.ordered) {
      return style;
    }

    final hasTabular = style.fontFeatures?.contains(
      const FontFeature.tabularFigures(),
    );
    if (hasTabular == true) {
      return style;
    }
    return style.copyWith(
      fontFeatures: [
        ...?style.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }
}
