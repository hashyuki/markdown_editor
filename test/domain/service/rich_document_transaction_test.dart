import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/rich_document.dart';
import 'package:markdown_editor/src/domain/service/rich_document_transaction.dart';

void main() {
  group('RichDocumentTransaction', () {
    test('insert text into a paragraph block', () {
      final document = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'Hello')],
      );

      const command = InsertTextCommand(
        blockId: 'b1',
        offset: 5,
        text: ' world',
      );
      final result = command.apply(document);

      expect(result.blockById('b1').plainText, 'Hello world');
    });

    test('split block into two blocks', () {
      final document = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'Hello world')],
      );

      const command = SplitBlockCommand(
        blockId: 'b1',
        offset: 5,
        newBlockId: 'b2',
      );
      final result = command.apply(document);

      expect(result.blocks.length, 2);
      expect(result.blocks[0].id, 'b1');
      expect(result.blocks[0].plainText, 'Hello');
      expect(result.blocks[1].id, 'b2');
      expect(result.blocks[1].plainText, ' world');
    });

    test('merge current block with previous block', () {
      final document = RichDocument(
        blocks: <BlockNode>[
          BlockNode.paragraph(id: 'b1', text: 'Hello'),
          BlockNode.paragraph(id: 'b2', text: ' world'),
        ],
      );

      const command = MergeWithPreviousBlockCommand(blockId: 'b2');
      final result = command.apply(document);

      expect(result.blocks.length, 1);
      expect(result.blocks.first.id, 'b1');
      expect(result.blocks.first.plainText, 'Hello world');
    });

    test('toggle inline mark on a range', () {
      final document = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'Hello world')],
      );

      const addBold = ToggleInlineMarkCommand(
        blockId: 'b1',
        start: 6,
        end: 11,
        mark: InlineMark.bold,
      );
      final added = addBold.apply(document).blockById('b1');

      expect(added.inlines.length, 2);
      expect(added.inlines[0].text, 'Hello ');
      expect(added.inlines[0].marks, isEmpty);
      expect(added.inlines[1].text, 'world');
      expect(added.inlines[1].marks, contains(InlineMark.bold));

      final removed = addBold.apply(RichDocument(blocks: <BlockNode>[added]));
      expect(removed.blockById('b1').inlines.single.marks, isEmpty);
    });

    test('set block type to heading with level', () {
      final document = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'Title')],
      );

      const command = SetBlockTypeCommand(
        blockId: 'b1',
        type: BlockType.heading,
        headingLevel: 2,
      );
      final result = command.apply(document).blockById('b1');

      expect(result.type, BlockType.heading);
      expect(result.headingLevel, 2);
    });

    test('applies multiple commands in one transaction', () {
      final document = RichDocument(
        blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'Hello world')],
      );

      const transaction = RichDocumentTransaction(
        commands: <RichDocumentEditCommand>[
          SplitBlockCommand(blockId: 'b1', offset: 5, newBlockId: 'b2'),
          SetBlockTypeCommand(
            blockId: 'b2',
            type: BlockType.heading,
            headingLevel: 3,
          ),
        ],
      );

      final result = transaction.apply(document);

      expect(result.blocks.length, 2);
      expect(result.blockById('b1').plainText, 'Hello');
      expect(result.blockById('b2').type, BlockType.heading);
      expect(result.blockById('b2').headingLevel, 3);
    });
  });
}
