import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/line_syntax.dart';
import 'package:markdown_editor/src/domain/service/line_syntax_parser.dart';

void main() {
  group('MarkdownLineSyntaxParser list parsing', () {
    const parser = MarkdownLineSyntaxParser();

    test('parses unordered list with *, +, - when followed by a space', () {
      final star = parser.parse('* item');
      final plus = parser.parse('+ item');
      final minus = parser.parse('- item');

      expect(star.list?.type, ListType.unordered);
      expect(star.list?.marker, '*');
      expect(star.list?.indent, 0);

      expect(plus.list?.type, ListType.unordered);
      expect(plus.list?.marker, '+');
      expect(plus.list?.indent, 0);

      expect(minus.list?.type, ListType.unordered);
      expect(minus.list?.marker, '-');
      expect(minus.list?.indent, 0);
    });

    test('does not parse unordered list without a trailing space', () {
      expect(parser.parse('*item').list, isNull);
      expect(parser.parse('+item').list, isNull);
      expect(parser.parse('-item').list, isNull);
    });

    test('parses ordered list with number dot and trailing space', () {
      final syntax = parser.parse('12. item');

      expect(syntax.list?.type, ListType.ordered);
      expect(syntax.list?.number, 12);
      expect(syntax.list?.indent, 0);
    });

    test('does not parse ordered list without a trailing space', () {
      expect(parser.parse('1.item').list, isNull);
    });

    test('does not parse escaped ordered list markers', () {
      expect(parser.parse(r'1\. item').list, isNull);
      expect(parser.parse(r'12\. item').list, isNull);
    });

    test('keeps indentation information for nested list items', () {
      final unordered = parser.parse('  - child');
      final ordered = parser.parse('    1. child');

      expect(unordered.list?.type, ListType.unordered);
      expect(unordered.list?.indent, 1);

      expect(ordered.list?.type, ListType.ordered);
      expect(ordered.list?.indent, 2);
    });

    test('does not parse list markers with non-two-space indentation', () {
      expect(parser.parse(' - child').list, isNull);
      expect(parser.parse('   - child').list, isNull);
      expect(parser.parse('\t- child').list, isNull);
    });
  });
}
