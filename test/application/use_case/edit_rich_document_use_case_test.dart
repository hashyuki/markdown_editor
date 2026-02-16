import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  group('EditRichDocumentUseCase', () {
    const useCase = EditRichDocumentUseCase();

    test('insertText appends at caret', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 2),
        ),
      );

      final next = useCase.insertText(state, 'x');
      expect(next.document.blockById('b1').plainText, 'abx');
      expect(next.selection.extent.offset, 3);
    });

    test('insertNewLine splits block', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 1),
        ),
      );

      final next = useCase.insertNewLine(state);
      expect(next.document.blocks.length, 2);
      expect(next.document.blocks[0].plainText, 'a');
      expect(next.document.blocks[1].plainText, 'b');
      expect(next.selection.extent.blockId, next.document.blocks[1].id);
      expect(next.selection.extent.offset, 0);
    });

    test('backspace merges with previous block at start', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            BlockNode.paragraph(id: 'b1', text: 'ab'),
            BlockNode.paragraph(id: 'b2', text: 'cd'),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b2', offset: 0),
        ),
      );

      final next = useCase.backspace(state);
      expect(next.document.blocks.length, 1);
      expect(next.document.blocks.first.plainText, 'abcd');
      expect(next.selection.extent.blockId, 'b1');
      expect(next.selection.extent.offset, 2);
    });

    test('selectAll expands selection to whole document', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            BlockNode.paragraph(id: 'b1', text: 'ab'),
            BlockNode.paragraph(id: 'b2', text: 'cd'),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 1),
        ),
      );

      final next = useCase.selectAll(state);
      expect(next.selection.base.blockId, 'b1');
      expect(next.selection.base.offset, 0);
      expect(next.selection.extent.blockId, 'b2');
      expect(next.selection.extent.offset, 2);
      expect(next.selection.isCollapsed, isFalse);
    });

    test('deleteSelection removes selected range and collapses caret', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'abcdef')],
        ),
        selection: const RichSelection(
          base: RichTextPosition(blockId: 'b1', offset: 1),
          extent: RichTextPosition(blockId: 'b1', offset: 4),
        ),
      );

      final next = useCase.deleteSelection(state);
      expect(next.document.blockById('b1').plainText, 'aef');
      expect(next.selection.isCollapsed, isTrue);
      expect(next.selection.extent.offset, 1);
    });

    test('backspace on last char in single heading resets to paragraph', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.heading,
              headingLevel: 1,
              inlines: <InlineText>[InlineText(text: 'a')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 1),
        ),
      );

      final next = useCase.backspace(state);
      final block = next.document.blockById('b1');
      expect(block.type, BlockType.paragraph);
      expect(block.headingLevel, isNull);
      expect(block.textLength, 0);
    });

    test('typing "# " at line start converts paragraph to heading', () {
      final initial = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      final afterHash = useCase.insertText(initial, '#');
      expect(afterHash.document.blockById('b1').type, BlockType.paragraph);
      expect(afterHash.document.blockById('b1').plainText, '#');

      final afterSpace = useCase.insertText(afterHash, ' ');
      final block = afterSpace.document.blockById('b1');
      expect(block.type, BlockType.heading);
      expect(block.headingLevel, 1);
      expect(block.plainText, '# ');
      expect(afterSpace.selection.extent.offset, 2);
    });

    test('typing "###### " at line start converts paragraph to h6', () {
      var state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      for (var i = 0; i < 6; i++) {
        state = useCase.insertText(state, '#');
      }
      final next = useCase.insertText(state, ' ');
      final block = next.document.blockById('b1');
      expect(block.type, BlockType.heading);
      expect(block.headingLevel, 6);
      expect(block.plainText, '###### ');
    });

    test('typing "####### " does not convert to heading', () {
      var state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      for (var i = 0; i < 7; i++) {
        state = useCase.insertText(state, '#');
      }
      final next = useCase.insertText(state, ' ');
      final block = next.document.blockById('b1');
      expect(block.type, BlockType.paragraph);
      expect(block.plainText, '####### ');
    });

    test('enter on heading creates paragraph on next line', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.heading,
              headingLevel: 1,
              inlines: <InlineText>[InlineText(text: 'title')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 5),
        ),
      );

      final next = useCase.insertNewLine(state);
      expect(next.document.blocks.length, 2);
      expect(next.document.blocks.first.type, BlockType.heading);
      expect(next.document.blocks.last.type, BlockType.paragraph);
      expect(next.selection.extent.blockId, next.document.blocks.last.id);
      expect(next.selection.extent.offset, 0);
    });

    test('heading level follows edited marker count', () {
      var state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      state = useCase.insertText(state, '#');
      state = useCase.insertText(state, '#');
      state = useCase.insertText(state, '#');
      state = useCase.insertText(state, ' ');
      expect(state.document.blockById('b1').type, BlockType.heading);
      expect(state.document.blockById('b1').headingLevel, 3);

      state = useCase.backspace(state); // remove trailing space -> "###"
      state = useCase.backspace(state); // "##"
      state = useCase.backspace(state); // "#"
      expect(state.document.blockById('b1').type, BlockType.paragraph);

      state = useCase.insertText(state, ' ');
      state = useCase.insertText(state, 'a');
      state = useCase.insertText(state, 'a');
      state = useCase.insertText(state, 'a');

      final block = state.document.blockById('b1');
      expect(block.type, BlockType.heading);
      expect(block.headingLevel, 1);
      expect(block.plainText, '# aaa');
    });

    test('typing "- " converts paragraph to bullet list item', () {
      final initial = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      final afterDash = useCase.insertText(initial, '-');
      final afterSpace = useCase.insertText(afterDash, ' ');
      final block = afterSpace.document.blockById('b1');
      expect(block.type, BlockType.bulletListItem);
      expect(block.indent, 0);
      expect(block.plainText, '- ');
    });

    test('typing "* " and "+ " converts paragraph to bullet list item', () {
      var state1 = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );
      state1 = useCase.insertText(state1, '*');
      state1 = useCase.insertText(state1, ' ');
      expect(state1.document.blockById('b1').type, BlockType.bulletListItem);

      var state2 = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b2', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b2', offset: 0),
        ),
      );
      state2 = useCase.insertText(state2, '+');
      state2 = useCase.insertText(state2, ' ');
      expect(state2.document.blockById('b2').type, BlockType.bulletListItem);
    });

    test('enter on non-empty bullet item continues list', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.bulletListItem,
              indent: 1,
              inlines: <InlineText>[InlineText(text: '  - item')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 8),
        ),
      );

      final next = useCase.insertNewLine(state);
      expect(next.document.blocks.length, 2);
      final created = next.document.blocks.last;
      expect(created.type, BlockType.bulletListItem);
      expect(created.indent, 1);
      expect(created.plainText, '  - ');
      expect(next.selection.extent.offset, 4);
    });

    test('enter on empty nested bullet item outdents one level', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.bulletListItem,
              indent: 2,
              inlines: <InlineText>[InlineText(text: '    - ')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 6),
        ),
      );

      final next = useCase.insertNewLine(state);
      final block = next.document.blockById('b1');
      expect(block.type, BlockType.bulletListItem);
      expect(block.indent, 1);
      expect(block.plainText, '  - ');
      expect(next.selection.extent.offset, 4);
    });

    test('enter on empty top-level bullet item exits list', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.bulletListItem,
              indent: 0,
              inlines: <InlineText>[InlineText(text: '- ')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 2),
        ),
      );

      final next = useCase.insertNewLine(state);
      final block = next.document.blockById('b1');
      expect(block.type, BlockType.paragraph);
      expect(block.plainText, '');
      expect(next.selection.extent.offset, 0);
    });

    test('tab/shift+tab changes list indentation by 2 spaces', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.bulletListItem,
              indent: 0,
              inlines: <InlineText>[InlineText(text: '- item')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 2),
        ),
      );

      final indented = useCase.indentListItem(state);
      expect(indented.document.blockById('b1').indent, 1);
      expect(indented.document.blockById('b1').plainText, '  - item');

      final outdented = useCase.outdentListItem(indented);
      expect(outdented.document.blockById('b1').indent, 0);
      expect(outdented.document.blockById('b1').plainText, '- item');
    });

    test('typing "1. " converts paragraph to ordered list item', () {
      var state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      state = useCase.insertText(state, '1');
      state = useCase.insertText(state, '.');
      state = useCase.insertText(state, ' ');
      final block = state.document.blockById('b1');
      expect(block.type, BlockType.orderedListItem);
      expect(block.indent, 0);
      expect(block.plainText, '1. ');
    });

    test('enter on non-empty ordered item continues ordered list', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            const BlockNode(
              id: 'b1',
              type: BlockType.orderedListItem,
              indent: 0,
              inlines: <InlineText>[InlineText(text: '1. item')],
            ),
          ],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 7),
        ),
      );

      final next = useCase.insertNewLine(state);
      expect(next.document.blocks.length, 2);
      final created = next.document.blocks.last;
      expect(created.type, BlockType.orderedListItem);
      expect(created.indent, 0);
      expect(created.plainText, '1. ');
      expect(next.selection.extent.offset, 3);
    });

    test('selectedPlainText returns multi-block text with newlines', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[
            BlockNode.paragraph(id: 'b1', text: 'abc'),
            BlockNode.paragraph(id: 'b2', text: 'xyz'),
          ],
        ),
        selection: const RichSelection(
          base: RichTextPosition(blockId: 'b1', offset: 1),
          extent: RichTextPosition(blockId: 'b2', offset: 2),
        ),
      );

      final selected = useCase.selectedPlainText(state);
      expect(selected, 'bc\nxy');
    });

    test(
      'selectedPlainText returns current line when selection is collapsed',
      () {
        final state = RichDocumentEditorState(
          document: RichDocument(
            blocks: <BlockNode>[
              BlockNode.paragraph(id: 'b1', text: 'line-1'),
              BlockNode.paragraph(id: 'b2', text: 'line-2'),
            ],
          ),
          selection: RichSelection.collapsed(
            const RichTextPosition(blockId: 'b2', offset: 2),
          ),
        );

        final selected = useCase.selectedPlainText(state);
        expect(selected, 'line-2');
      },
    );

    test('pastePlainText splits lines into multiple blocks', () {
      final state = RichDocumentEditorState(
        document: RichDocument(
          blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
        ),
        selection: RichSelection.collapsed(
          const RichTextPosition(blockId: 'b1', offset: 0),
        ),
      );

      final next = useCase.pastePlainText(state, 'hello\nworld');
      expect(next.document.blocks.length, 2);
      expect(next.document.blocks[0].plainText, 'hello');
      expect(next.document.blocks[1].plainText, 'world');
    });

    test(
      'pastePlainText with bullet lines does not duplicate list markers',
      () {
        final state = RichDocumentEditorState(
          document: RichDocument(
            blocks: <BlockNode>[
              const BlockNode(
                id: 'b1',
                type: BlockType.bulletListItem,
                indent: 0,
                inlines: <InlineText>[InlineText(text: '- ')],
              ),
            ],
          ),
          selection: RichSelection.collapsed(
            const RichTextPosition(blockId: 'b1', offset: 2),
          ),
        );

        final next = useCase.pastePlainText(state, '- aa\n- bb\n- cc');
        expect(next.document.blocks.length, 3);
        expect(next.document.blocks[0].plainText, '- aa');
        expect(next.document.blocks[1].plainText, '- bb');
        expect(next.document.blocks[2].plainText, '- cc');
        expect(next.document.blocks[0].type, BlockType.bulletListItem);
        expect(next.document.blocks[1].type, BlockType.bulletListItem);
        expect(next.document.blocks[2].type, BlockType.bulletListItem);
      },
    );
  });
}
