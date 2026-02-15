import 'package:markdown_editor/src/domain/model/text_edit_state.dart';
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
      const value = TextEditState(
        text: '- item',
        selectionStart: 6,
        selectionEnd: 6,
      );

      final adjusted = service.applyEnter(value: value);

      expect(adjusted.text, '- item\n- ');
      expect(adjusted.selectionEnd, 9);
    });

    test('exits list on enter for empty list item', () {
      const value = TextEditState(
        text: '- item\n- ',
        selectionStart: 9,
        selectionEnd: 9,
      );

      final adjusted = service.applyEnter(value: value);

      expect(adjusted.text, '- item\n\n');
      expect(adjusted.selectionEnd, 8);
    });

    test(
      'on nested empty item, second enter outdents one level and continues',
      () {
        const value = TextEditState(
          text: '1. parent\n   1. ',
          selectionStart: 16,
          selectionEnd: 16,
        );

        final adjusted = service.applyEnter(value: value);

        expect(adjusted.text, '1. parent\n1. ');
        expect(adjusted.selectionEnd, 13);
      },
    );

    test('keeps ordered list number as 1 on enter', () {
      const value = TextEditState(
        text: '1. item',
        selectionStart: 7,
        selectionEnd: 7,
      );

      final adjusted = service.applyEnter(value: value);

      expect(adjusted.text, '1. item\n1. ');
      expect(adjusted.selectionEnd, 11);
    });

    test('exits list on backspace for empty list marker', () {
      const value = TextEditState(
        text: '- ',
        selectionStart: 2,
        selectionEnd: 2,
      );

      final adjusted = service.applyBackspace(value: value);

      expect(adjusted.text, '');
      expect(adjusted.selectionEnd, 0);
    });

    test('indents list line on tab', () {
      const value = TextEditState(
        text: '- item',
        selectionStart: 6,
        selectionEnd: 6,
      );

      final adjusted = service.applyTabIndentation(
        value: value,
        outdent: false,
      );

      expect(adjusted.text, '  - item');
      expect(adjusted.selectionEnd, 8);
    });

    test('outdents nested list line on shift+tab', () {
      const value = TextEditState(
        text: '  - item',
        selectionStart: 8,
        selectionEnd: 8,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '- item');
      expect(adjusted.selectionEnd, 6);
    });

    test(
      'ordered list with one digit indents by +3 and resets number to 1',
      () {
        const value = TextEditState(
          text: '9. item',
          selectionStart: 7,
          selectionEnd: 7,
        );

        final adjusted = service.applyTabIndentation(
          value: value,
          outdent: false,
        );

        expect(adjusted.text, '   1. item');
        expect(adjusted.selectionEnd, 10);
      },
    );

    test(
      'ordered list with two digits indents by +4 and resets number to 1',
      () {
        const value = TextEditState(
          text: '12. item',
          selectionStart: 8,
          selectionEnd: 8,
        );

        final adjusted = service.applyTabIndentation(
          value: value,
          outdent: false,
        );

        expect(adjusted.text, '    1. item');
        expect(adjusted.selectionEnd, 11);
      },
    );

    test('outdented ordered item keeps text number as 1', () {
      const text = '1. a\n2. b\n   1. a\n   2. b\n   3. c';
      final value = TextEditState(
        text: text,
        selectionStart: text.length,
        selectionEnd: text.length,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '1. a\n2. b\n   1. a\n   2. b\n1. c');
    });

    test('tab indents all selected list lines', () {
      const text = '- a\n- b\n- c';
      final value = TextEditState(
        text: text,
        selectionStart: 0,
        selectionEnd: text.length,
      );

      final adjusted = service.applyTabIndentation(
        value: value,
        outdent: false,
      );

      expect(adjusted.text, '  - a\n  - b\n  - c');
      expect(adjusted.selectionStart, 2);
      expect(adjusted.selectionEnd, '  - a\n  - b\n  - c'.length);
    });

    test('shift+tab outdents all selected list lines', () {
      const text = '  - a\n  - b\n  - c';
      final value = TextEditState(
        text: text,
        selectionStart: 0,
        selectionEnd: text.length,
      );

      final adjusted = service.applyTabIndentation(value: value, outdent: true);

      expect(adjusted.text, '- a\n- b\n- c');
      expect(adjusted.selectionStart, 0);
      expect(adjusted.selectionEnd, '- a\n- b\n- c'.length);
    });
  });
}
