import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/rich_document.dart';
import 'package:markdown_editor/src/domain/service/markdown_to_rich_document_converter.dart';

void main() {
  group('MarkdownToRichDocumentConverter', () {
    late MarkdownToRichDocumentConverter converter;

    setUp(() {
      converter = MarkdownToRichDocumentConverter();
    });

    test('parses heading and paragraph', () {
      final doc = converter.convert('# Title\nBody text');

      expect(doc.blocks.length, 2);
      expect(doc.blocks[0].type, BlockType.heading);
      expect(doc.blocks[0].headingLevel, 1);
      expect(doc.blocks[0].plainText, 'Title');
      expect(doc.blocks[1].type, BlockType.paragraph);
      expect(doc.blocks[1].plainText, 'Body text');
    });

    test('parses list items', () {
      final doc = converter.convert('- first\n1. second');

      expect(doc.blocks[0].type, BlockType.bulletListItem);
      expect(doc.blocks[0].plainText, 'first');
      expect(doc.blocks[1].type, BlockType.orderedListItem);
      expect(doc.blocks[1].plainText, 'second');
    });

    test('treats fenced code lines as plain paragraphs for now', () {
      const source = '```dart\nfinal x = 1;\n```';
      final doc = converter.convert(source);

      expect(doc.blocks.length, 3);
      expect(doc.blocks[0].type, BlockType.paragraph);
      expect(doc.blocks[0].plainText, '```dart');
      expect(doc.blocks[1].type, BlockType.paragraph);
      expect(doc.blocks[1].plainText, 'final x = 1;');
      expect(doc.blocks[2].plainText, '```');
    });

    test('treats inline markdown markers as plain text for now', () {
      final doc = converter.convert(
        '**bold** *italic* `code` [site](https://x.dev)',
      );
      final inlines = doc.blocks[0].inlines;

      expect(inlines.length, 1);
      expect(
        inlines.single.text,
        '**bold** *italic* `code` [site](https://x.dev)',
      );
      expect(inlines.single.marks, isEmpty);
      expect(inlines.single.link, isNull);
    });
  });
}
