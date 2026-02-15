import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/service/line_syntax_parser.dart';
import 'package:markdown_editor/src/domain/service/markdown_list_editing_service.dart';

void main() {
  group('MarkdownListEditingService', () {
    late MarkdownListEditingService service;

    setUp(() {
      service = MarkdownListEditingService(
        parser: const MarkdownLineSyntaxParser(),
      );
    });

    test('continues unordered list on enter', () {
      const oldValue = EditorTextSnapshot(
        text: '- item',
        baseOffset: 6,
        extentOffset: 6,
      );
      const newValue = EditorTextSnapshot(
        text: '- item\n',
        baseOffset: 7,
        extentOffset: 7,
      );

      final adjusted = service.applyRules(
        oldValue: oldValue,
        newValue: newValue,
      );

      expect(adjusted.text, '- item\n- ');
      expect(adjusted.extentOffset, 9);
    });

    test('exits list on enter for empty list item', () {
      const oldValue = EditorTextSnapshot(
        text: '- item\n- ',
        baseOffset: 9,
        extentOffset: 9,
      );
      const newValue = EditorTextSnapshot(
        text: '- item\n- \n',
        baseOffset: 10,
        extentOffset: 10,
      );

      final adjusted = service.applyRules(
        oldValue: oldValue,
        newValue: newValue,
      );

      expect(adjusted.text, '- item\n\n');
      expect(adjusted.extentOffset, 8);
    });

    test(
      'on nested empty item, second enter outdents one level and continues',
      () {
        const oldValue = EditorTextSnapshot(
          text: '1. parent\n   1. ',
          baseOffset: 16,
          extentOffset: 16,
        );
        const newValue = EditorTextSnapshot(
          text: '1. parent\n   1. \n',
          baseOffset: 17,
          extentOffset: 17,
        );

        final adjusted = service.applyRules(
          oldValue: oldValue,
          newValue: newValue,
        );

        expect(adjusted.text, '1. parent\n1. ');
        expect(adjusted.extentOffset, 13);
      },
    );

    test('keeps ordered list number as 1 on enter', () {
      const oldValue = EditorTextSnapshot(
        text: '1. item',
        baseOffset: 7,
        extentOffset: 7,
      );
      const newValue = EditorTextSnapshot(
        text: '1. item\n',
        baseOffset: 8,
        extentOffset: 8,
      );

      final adjusted = service.applyRules(
        oldValue: oldValue,
        newValue: newValue,
      );

      expect(adjusted.text, '1. item\n1. ');
      expect(adjusted.extentOffset, 11);
    });

    test('exits list on backspace for empty list marker', () {
      const oldValue = EditorTextSnapshot(
        text: '- ',
        baseOffset: 2,
        extentOffset: 2,
      );
      const newValue = EditorTextSnapshot(
        text: '-',
        baseOffset: 1,
        extentOffset: 1,
      );

      final adjusted = service.applyRules(
        oldValue: oldValue,
        newValue: newValue,
      );

      expect(adjusted.text, '');
      expect(adjusted.extentOffset, 0);
    });

    test('indents list line on tab', () {
      const value = EditorTextSnapshot(
        text: '- item',
        baseOffset: 6,
        extentOffset: 6,
      );

      final adjusted = service.applyTabIndentation(
        value: value,
        outdent: false,
      );

      expect(adjusted.text, '  - item');
      expect(adjusted.extentOffset, 8);
    });

    test('outdents nested list line on shift+tab', () {
      const value = EditorTextSnapshot(
        text: '  - item',
        baseOffset: 8,
        extentOffset: 8,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '- item');
      expect(adjusted.extentOffset, 6);
    });

    test(
      'ordered list with one digit indents by +3 and resets number to 1',
      () {
        const value = EditorTextSnapshot(
          text: '9. item',
          baseOffset: 7,
          extentOffset: 7,
        );

        final adjusted = service.applyTabIndentation(
          value: value,
          outdent: false,
        );

        expect(adjusted.text, '   1. item');
        expect(adjusted.extentOffset, 10);
      },
    );

    test(
      'ordered list with two digits indents by +4 and resets number to 1',
      () {
        const value = EditorTextSnapshot(
          text: '12. item',
          baseOffset: 8,
          extentOffset: 8,
        );

        final adjusted = service.applyTabIndentation(
          value: value,
          outdent: false,
        );

        expect(adjusted.text, '    1. item');
        expect(adjusted.extentOffset, 11);
      },
    );

    test('outdented ordered item keeps text number as 1', () {
      const text = '1. a\n2. b\n   1. a\n   2. b\n   3. c';
      final value = EditorTextSnapshot(
        text: text,
        baseOffset: text.length,
        extentOffset: text.length,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '1. a\n2. b\n   1. a\n   2. b\n1. c');
    });

    test('tab indents all selected list lines', () {
      const text = '- a\n- b\n- c';
      final value = EditorTextSnapshot(
        text: text,
        baseOffset: 0,
        extentOffset: text.length,
      );

      final adjusted = service.applyTabIndentation(
        value: value,
        outdent: false,
      );

      expect(adjusted.text, '  - a\n  - b\n  - c');
      expect(adjusted.baseOffset, 2);
      expect(adjusted.extentOffset, '  - a\n  - b\n  - c'.length);
    });

    test('shift+tab outdents all selected list lines', () {
      const text = '  - a\n  - b\n  - c';
      final value = EditorTextSnapshot(
        text: text,
        baseOffset: 0,
        extentOffset: text.length,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '- a\n- b\n- c');
      expect(adjusted.baseOffset, 0);
      expect(adjusted.extentOffset, '- a\n- b\n- c'.length);
    });
  });
}
