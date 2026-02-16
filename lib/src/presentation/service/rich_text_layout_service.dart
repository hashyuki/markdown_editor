import 'package:flutter/widgets.dart';

class RichTextLayoutService {
  const RichTextLayoutService();

  Rect? caretRectForOffset({
    required BuildContext context,
    required String text,
    required int textLength,
    required TextStyle textStyle,
    required double maxWidth,
    required int? offset,
    int logicalToVisualOffsetDelta = 0,
    double caretWidth = 1.5,
  }) {
    if (offset == null) {
      return null;
    }
    final clampedOffset =
        (offset.clamp(0, textLength) + logicalToVisualOffsetDelta).clamp(
          0,
          text.length,
        );
    final textForLayout = text.isEmpty ? ' ' : text;
    final textPainter = TextPainter(
      text: TextSpan(text: textForLayout, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: null,
    )..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);

    final offsetForCaret = textPainter.getOffsetForCaret(
      TextPosition(offset: clampedOffset),
      Rect.zero,
    );
    return Rect.fromLTWH(
      offsetForCaret.dx,
      offsetForCaret.dy,
      caretWidth,
      textPainter.preferredLineHeight,
    );
  }

  int textOffsetFromLocalPosition({
    required BuildContext context,
    required String text,
    required int textLength,
    required Offset localPosition,
    required TextStyle textStyle,
    required double maxWidth,
    int logicalToVisualOffsetDelta = 0,
  }) {
    final textForLayout = text.isEmpty ? ' ' : text;
    final textPainter = TextPainter(
      text: TextSpan(text: textForLayout, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: null,
    )..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);

    final clamped = Offset(
      localPosition.dx.clamp(0.0, textPainter.width),
      localPosition.dy.clamp(0.0, textPainter.height),
    );
    final position = textPainter.getPositionForOffset(clamped);
    final logicalOffset = position.offset - logicalToVisualOffsetDelta;
    return logicalOffset.clamp(0, textLength);
  }
}
