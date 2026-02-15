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

    test('increments ordered list number on enter', () {
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

      expect(adjusted.text, '1. item\n2. ');
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
  });
}
