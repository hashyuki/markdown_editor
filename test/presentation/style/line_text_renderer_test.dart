import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/line_syntax.dart';
import 'package:markdown_editor/src/presentation/style/line_text_renderer.dart';

void main() {
  group('MarkdownLineTextRenderer', () {
    const renderer = MarkdownLineTextRenderer();

    test('replaces unordered marker with bullet', () {
      final rendered = renderer.render(
        lineText: '- item',
        syntax: const LineSyntax(
          list: ListSyntax.unordered(indent: 0, marker: '-'),
        ),
      );

      expect(rendered, '• item');
    });

    test('keeps ordered indentation spaces as-is', () {
      final rendered = renderer.render(
        lineText: '    1. item',
        syntax: const LineSyntax(
          list: ListSyntax.ordered(indent: 4, number: 1),
        ),
      );

      expect(rendered, '    1. item');
      expect(rendered.length, '    1. item'.length);
    });

    test('renders ordered display number independent from text number', () {
      final rendered = renderer.render(
        lineText: '   1. item',
        syntax: const LineSyntax(
          list: ListSyntax.ordered(indent: 3, number: 1),
        ),
        orderedDisplayNumber: 2,
      );

      expect(rendered, '   2. item');
    });
  });
}
