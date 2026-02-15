import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  group('SimpleTextEditor heading behavior', () {
    testWidgets('applies heading style to markdown heading line', (
      tester,
    ) async {
      final controller = TextEditingController(text: '# Heading');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final context = tester.element(find.byType(EditableText));
      final textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      final leafSpans = _collectLeafSpans(textSpan);
      final headingSpan = leafSpans.singleWhere(
        (span) => span.text == '# Heading',
      );

      expect(headingSpan.style?.fontSize, 26);
      expect(headingSpan.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('updates cursor height based on selected line style', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'plain\n# Heading');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      final paragraphCursorHeight = tester
          .widget<EditableText>(find.byType(EditableText))
          .cursorHeight!;

      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();
      final headingCursorHeight = tester
          .widget<EditableText>(find.byType(EditableText))
          .cursorHeight!;

      expect(headingCursorHeight, greaterThan(paragraphCursorHeight));
    });

    testWidgets('underlines composing text while keeping markdown style', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      controller.value = const TextEditingValue(
        text: '# Hello',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 2, end: 5),
      );
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final context = tester.element(find.byType(EditableText));
      final textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      final leafSpans = _collectLeafSpans(textSpan);
      final composingSpan = leafSpans.singleWhere((span) => span.text == 'Hel');

      expect(
        composingSpan.style?.decoration?.contains(TextDecoration.underline),
        isTrue,
      );
      expect(composingSpan.style?.fontSize, 26);
    });

    testWidgets('preserves existing text decoration when composing', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleTextEditor(
              controller: controller,
              config: const SimpleTextEditorConfig(
                headingStyles: <int, TextStyle>{
                  1: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                  ),
                },
              ),
            ),
          ),
        ),
      );

      controller.value = const TextEditingValue(
        text: '# Hello',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 2, end: 5),
      );
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final context = tester.element(find.byType(EditableText));
      final textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      final leafSpans = _collectLeafSpans(textSpan);
      final composingSpan = leafSpans.singleWhere((span) => span.text == 'Hel');
      final decoration = composingSpan.style?.decoration;

      expect(decoration?.contains(TextDecoration.underline), isTrue);
      expect(decoration?.contains(TextDecoration.lineThrough), isTrue);
    });

    testWidgets('applies composing underline across line breaks', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      controller.value = const TextEditingValue(
        text: '# One\n# Two',
        selection: TextSelection.collapsed(offset: 10),
        composing: TextRange(start: 4, end: 7),
      );
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final context = tester.element(find.byType(EditableText));
      final textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      final leafSpans = _collectLeafSpans(textSpan);
      final newlineSpan = leafSpans.singleWhere((span) => span.text == '\n');

      expect(
        newlineSpan.style?.decoration?.contains(TextDecoration.underline),
        isTrue,
      );
    });

    testWidgets('keeps editor size after text input', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SimpleTextEditor(controller: controller),
            ),
          ),
        ),
      );

      final sizeBefore = tester.getSize(find.byType(SimpleTextEditor));
      await tester.enterText(
        find.byKey(const Key('simple_text_editor_input')),
        '# Heading 1\ntext',
      );
      await tester.pump();
      final sizeAfter = tester.getSize(find.byType(SimpleTextEditor));

      expect(sizeAfter, sizeBefore);
    });

    testWidgets('syncs text when external controller is replaced', (
      tester,
    ) async {
      final firstController = TextEditingController(text: '# First');
      final secondController = TextEditingController(text: '# Second');
      addTearDown(firstController.dispose);
      addTearDown(secondController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: firstController)),
        ),
      );
      expect(find.text('# First'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: secondController)),
        ),
      );
      await tester.pump();
      expect(find.text('# Second'), findsOneWidget);

      secondController.text = '# Updated';
      await tester.pump();
      expect(find.text('# Updated'), findsOneWidget);
    });

    testWidgets('applies config map mutations on rebuild', (tester) async {
      final controller = TextEditingController(text: '# Heading');
      addTearDown(controller.dispose);
      final headingStyles = <int, TextStyle>{
        1: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      };
      final config = SimpleTextEditorConfig(headingStyles: headingStyles);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleTextEditor(controller: controller, config: config),
          ),
        ),
      );

      var editable = tester.widget<EditableText>(find.byType(EditableText));
      var context = tester.element(find.byType(EditableText));
      var textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      var headingSpan = _collectLeafSpans(
        textSpan,
      ).singleWhere((span) => span.text == '# Heading');
      expect(headingSpan.style?.fontSize, 26);

      headingStyles[1] = const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleTextEditor(controller: controller, config: config),
          ),
        ),
      );
      await tester.pump();

      editable = tester.widget<EditableText>(find.byType(EditableText));
      context = tester.element(find.byType(EditableText));
      textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      headingSpan = _collectLeafSpans(
        textSpan,
      ).singleWhere((span) => span.text == '# Heading');
      expect(headingSpan.style?.fontSize, 30);
    });

    testWidgets('uses extent offset for reverse selections', (tester) async {
      final controller = TextEditingController(text: 'plain\n# Heading');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();
      final headingCursorHeight = tester
          .widget<EditableText>(find.byType(EditableText))
          .cursorHeight!;

      controller.selection = const TextSelection(
        baseOffset: 10,
        extentOffset: 2,
      );
      await tester.pump();
      final reverseSelectionCursorHeight = tester
          .widget<EditableText>(find.byType(EditableText))
          .cursorHeight!;

      expect(reverseSelectionCursorHeight, lessThan(headingCursorHeight));
    });

    testWidgets('renders unordered list markers as bullets', (tester) async {
      final controller = TextEditingController(
        text: '* one\n  - two\n+ three\n1. four\n1\\. escaped',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final context = tester.element(find.byType(EditableText));
      final textSpan = editable.controller.buildTextSpan(
        context: context,
        style: editable.style,
        withComposing: true,
      );
      final leafSpans = _collectLeafSpans(textSpan);
      final leafTexts = leafSpans.map((span) => span.text);

      expect(leafTexts, contains('• one'));
      expect(leafTexts, contains('  • two'));
      expect(leafTexts, contains('• three'));
      expect(leafTexts, contains('1. four'));
      expect(leafTexts, contains(r'1\. escaped'));
      final orderedSpan = leafSpans.singleWhere(
        (span) => span.text == '1. four',
      );
      expect(
        orderedSpan.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('pressing enter continues unordered list', (tester) async {
      final controller = TextEditingController(text: '- item');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.value = const TextEditingValue(
        text: '- item',
        selection: TextSelection.collapsed(offset: 6),
      );
      editable.controller.value = const TextEditingValue(
        text: '- item\n',
        selection: TextSelection.collapsed(offset: 7),
      );
      await tester.pump();

      expect(editable.controller.text, '- item\n- ');
      expect(editable.controller.selection.baseOffset, 9);
    });

    testWidgets('pressing enter on empty list item exits list', (tester) async {
      final controller = TextEditingController(text: '- item\n- ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.value = const TextEditingValue(
        text: '- item\n- ',
        selection: TextSelection.collapsed(offset: 9),
      );
      editable.controller.value = const TextEditingValue(
        text: '- item\n- \n',
        selection: TextSelection.collapsed(offset: 10),
      );
      await tester.pump();

      expect(editable.controller.text, '- item\n\n');
      expect(editable.controller.selection.baseOffset, 8);
    });

    testWidgets('backspace on empty list item exits list', (tester) async {
      final controller = TextEditingController(text: '- ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.value = const TextEditingValue(
        text: '- ',
        selection: TextSelection.collapsed(offset: 2),
      );
      editable.controller.value = const TextEditingValue(
        text: '-',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();

      expect(editable.controller.text, '');
      expect(editable.controller.selection.baseOffset, 0);
    });

    testWidgets('pressing enter continues ordered list with next number', (
      tester,
    ) async {
      final controller = TextEditingController(text: '1. item');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.value = const TextEditingValue(
        text: '1. item',
        selection: TextSelection.collapsed(offset: 7),
      );
      editable.controller.value = const TextEditingValue(
        text: '1. item\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pump();

      expect(editable.controller.text, '1. item\n2. ');
      expect(editable.controller.selection.baseOffset, 11);
    });

    testWidgets('allows interactive text selection', (tester) async {
      final controller = TextEditingController(text: 'selectable text');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SimpleTextEditor(controller: controller)),
        ),
      );

      final editableFinder = find.byType(EditableText);
      final editableState = tester.state<EditableTextState>(editableFinder);
      final localTapPosition = editableState.renderEditable
          .getLocalRectForCaret(const TextPosition(offset: 2))
          .center;
      final globalTapPosition =
          tester.getTopLeft(editableFinder) + localTapPosition;

      await tester.longPressAt(globalTapPosition);
      await tester.pumpAndSettle();

      expect(controller.selection.isCollapsed, isFalse);
      expect(controller.selection.textInside(controller.text), isNotEmpty);
    });
  });
}

List<TextSpan> _collectLeafSpans(TextSpan span) {
  final leaves = <TextSpan>[];

  void visit(InlineSpan current) {
    if (current is! TextSpan) {
      return;
    }
    final children = current.children;
    if (children == null || children.isEmpty) {
      leaves.add(current);
      return;
    }
    for (final child in children) {
      visit(child);
    }
  }

  visit(span);
  return leaves;
}
