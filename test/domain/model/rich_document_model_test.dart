import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/rich_document.dart';

void main() {
  group('RichDocument model', () {
    test('applies defensive copy for nested collections', () {
      final marks = <InlineMark>{InlineMark.bold};
      final inlines = <InlineText>[InlineText(text: 'abc', marks: marks)];
      final block = BlockNode(
        id: 'b1',
        type: BlockType.paragraph,
        inlines: inlines,
      );
      final blocks = <BlockNode>[block];
      final document = RichDocument(blocks: blocks);

      marks.clear();
      inlines.clear();
      blocks.clear();

      final persisted = document.blockById('b1');
      expect(document.blocks.length, 1);
      expect(persisted.inlines.length, 1);
      expect(persisted.inlines.first.marks, <InlineMark>{InlineMark.bold});
    });

    test('compares by value', () {
      final left = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'same')],
      );
      final right = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'same')],
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('non-list block cannot keep indent', () {
      expect(
        () => BlockNode(
          id: 'b1',
          type: BlockType.paragraph,
          indent: 1,
          inlines: <InlineText>[InlineText(text: 'x')],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
