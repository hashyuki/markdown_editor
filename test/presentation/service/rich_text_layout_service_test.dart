import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  group('RichTextLayoutService', () {
    const service = RichTextLayoutService();
    const style = TextStyle(fontSize: 16);

    testWidgets('caretRectForOffset returns rectangle in bounds', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final rect = service.caretRectForOffset(
        context: context,
        text: 'abc',
        textLength: 3,
        textStyle: style,
        maxWidth: 400,
        offset: 1,
      );

      expect(rect, isNotNull);
      expect(rect!.left, greaterThanOrEqualTo(0));
      expect(rect.height, greaterThan(0));
    });

    testWidgets('textOffsetFromLocalPosition clamps to text length', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final offset = service.textOffsetFromLocalPosition(
        context: context,
        text: 'abc',
        textLength: 3,
        localPosition: const Offset(999, 0),
        textStyle: style,
        maxWidth: 400,
      );

      expect(offset, 3);
    });
  });
}
