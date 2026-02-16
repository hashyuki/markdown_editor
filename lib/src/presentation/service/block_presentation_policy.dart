import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/model/rich_document.dart';

class BlockPresentationPolicy {
  const BlockPresentationPolicy();

  static const Map<int, TextStyle> _headingStyles = <int, TextStyle>{
    1: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.04),
    2: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.04),
    3: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.03),
    4: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.03),
    5: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.02),
    6: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.02),
  };

  double blockSpacingAfter(BlockNode current, BlockNode? next) {
    if (next == null) {
      return 0;
    }
    if (current.type != next.type) {
      return 8;
    }
    return 0.5;
  }

  TextStyle textStyleForBlock(TextStyle bodyStyle, BlockNode block) {
    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 1;
        return bodyStyle.merge(_headingStyles[level]);
      case BlockType.quote:
        return bodyStyle.copyWith(fontStyle: FontStyle.italic);
      case BlockType.bulletListItem:
      case BlockType.orderedListItem:
      case BlockType.codeBlock:
      case BlockType.table:
      case BlockType.paragraph:
        return bodyStyle;
    }
  }

  TextStyle headingRenderStyle(TextStyle bodyStyle, int level) {
    return bodyStyle.merge(_headingStyles[level]);
  }

  String editingMarkdownPrefixForBlock(BlockNode block) {
    final prefix = markdownPrefixForBlock(block);
    if (prefix.isEmpty) {
      return '';
    }
    if (hasExistingMarkdownMarker(block)) {
      return '';
    }
    return prefix;
  }

  String markdownPrefixForBlock(BlockNode block) {
    switch (block.type) {
      case BlockType.heading:
        final level = (block.headingLevel ?? 1).clamp(1, 6);
        return '${List<String>.filled(level, '#').join()} ';
      case BlockType.bulletListItem:
        return '${List<String>.filled(block.indent, '  ').join()}- ';
      case BlockType.orderedListItem:
        return '${List<String>.filled(block.indent, '  ').join()}1. ';
      case BlockType.quote:
        return '> ';
      case BlockType.codeBlock:
      case BlockType.table:
      case BlockType.paragraph:
        return '';
    }
  }

  bool hasExistingMarkdownMarker(BlockNode block) {
    final text = block.plainText;
    switch (block.type) {
      case BlockType.heading:
        return RegExp(r'^#{1,6}(\s|$)').hasMatch(text);
      case BlockType.bulletListItem:
        return RegExp(r'^\s*[-*+]\s').hasMatch(text);
      case BlockType.orderedListItem:
        return RegExp(r'^\s*\d+\.\s').hasMatch(text);
      case BlockType.quote:
        return RegExp(r'^\s*>\s?').hasMatch(text);
      case BlockType.codeBlock:
      case BlockType.table:
      case BlockType.paragraph:
        return false;
    }
  }

  int hiddenLeadingCharsForBullet(BlockNode block) {
    final match = RegExp(r'^((?:  )*)([-*+])\s').firstMatch(block.plainText);
    if (match == null) {
      return 0;
    }
    return match.end;
  }

  int hiddenLeadingCharsForOrdered(BlockNode block) {
    final match = RegExp(r'^((?:  )*)(\d+)\.\s').firstMatch(block.plainText);
    if (match == null) {
      return 0;
    }
    return match.end;
  }

  int orderedDisplayNumberInDocument(RichDocument document, BlockNode block) {
    final currentIndex = document.indexOfBlock(block.id);
    if (currentIndex == -1) {
      return 1;
    }
    final currentIndent = block.indent;
    var number = 1;
    for (var index = currentIndex - 1; index >= 0; index--) {
      final candidate = document.blocks[index];
      if (candidate.type != BlockType.orderedListItem) {
        break;
      }
      if (candidate.indent < currentIndent) {
        break;
      }
      if (candidate.indent > currentIndent) {
        continue;
      }
      number += 1;
    }
    return number;
  }

  double orderedMarkerWidth({
    required BuildContext context,
    required String markerText,
    required TextStyle style,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: markerText, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final digitCount = markerText.endsWith('.')
        ? markerText.length - 1
        : markerText.length;
    final unit = (style.fontSize ?? 16) * 0.5;
    final spacing = (digitCount + 2) * unit;
    return math.max(textPainter.width, spacing);
  }
}
