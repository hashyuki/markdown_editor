import 'package:flutter/material.dart';

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
    if (headingLevel == null) {
      return paragraphStyle;
    }
    return paragraphStyle.merge(headingStyles[headingLevel]);
  }
}
