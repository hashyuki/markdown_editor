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
    return headingLevel == null
        ? paragraphStyle
        : paragraphStyle.merge(headingStyles[headingLevel]);
  }
}

class OrderedListMonospaceStyleResolver implements LineStyleResolver {
  const OrderedListMonospaceStyleResolver({
    this.baseResolver = const HeadingLineStyleResolver(),
  });

  final LineStyleResolver baseResolver;

  @override
  TextStyle resolve({
    required TextStyle paragraphStyle,
    required LineSyntax syntax,
    required Map<int, TextStyle> headingStyles,
  }) {
    final style = baseResolver.resolve(
      paragraphStyle: paragraphStyle,
      syntax: syntax,
      headingStyles: headingStyles,
    );
    final list = syntax.list;
    if (list == null || list.type != ListType.ordered) {
      return style;
    }

    final hasTabular = style.fontFeatures?.contains(
      const FontFeature.tabularFigures(),
    );
    final fontFeatures = hasTabular == true
        ? style.fontFeatures
        : [...?style.fontFeatures, const FontFeature.tabularFigures()];

    return style.copyWith(
      fontFamily: 'monospace',
      fontFeatures: fontFeatures,
      fontFamilyFallback: const ['monospace'],
    );
  }
}
