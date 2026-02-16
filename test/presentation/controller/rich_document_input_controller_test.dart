import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  group('RichDocumentInputController', () {
    const controller = RichDocumentInputController();

    test('collapses selection and stores preferred column', () {
      final state = _stateWithText('abc');
      final next = controller.collapseSelection(
        state,
        const RichTextPosition(blockId: 'b1', offset: 2),
      );

      expect(next.selection.isCollapsed, isTrue);
      expect(next.selection.extent.offset, 2);
      expect(next.preferredColumn, 2);
    });

    test('arrow right key moves caret', () {
      final state = _stateWithText('abc');

      final next = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );

      expect(next, isNotNull);
      expect(next!.selection.extent.offset, 1);
    });

    test('character key inserts when editing enabled', () {
      final state = _stateWithText('ab');

      final next = controller.handleKeyDown(
        state.copyWith(
          selection: RichSelection.collapsed(
            const RichTextPosition(blockId: 'b1', offset: 2),
          ),
        ),
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.keyX,
          logicalKey: LogicalKeyboardKey.keyX,
          character: 'x',
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );

      expect(next, isNotNull);
      expect(next!.document.blockById('b1').plainText, 'abx');
    });

    test('character key is ignored when shortcut key pressed', () {
      final state = _stateWithText('ab');

      final next = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.keyC,
          logicalKey: LogicalKeyboardKey.keyC,
          character: 'c',
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{LogicalKeyboardKey.controlLeft},
      );

      expect(next, isNull);
    });

    test('cmd/ctrl+a selects all blocks', () {
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

      final next = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: 'a',
        ),
        enableEditing: false,
        pressedKeys: <LogicalKeyboardKey>{LogicalKeyboardKey.metaLeft},
      );

      expect(next, isNotNull);
      expect(next!.selection.base.blockId, 'b1');
      expect(next.selection.base.offset, 0);
      expect(next.selection.extent.blockId, 'b2');
      expect(next.selection.extent.offset, 2);
    });

    test('typing "# " converts current paragraph block to heading', () {
      final initial = _stateWithText('');
      final afterHash = controller.handleKeyDown(
        initial,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.digit3,
          logicalKey: LogicalKeyboardKey.numberSign,
          character: '#',
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );
      expect(afterHash, isNotNull);

      final afterSpace = controller.handleKeyDown(
        afterHash!,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          character: ' ',
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );
      expect(afterSpace, isNotNull);
      final block = afterSpace!.document.blockById('b1');
      expect(block.type, BlockType.heading);
      expect(block.headingLevel, 1);
      expect(block.plainText, '# ');
    });

    test('typing "###### " converts current paragraph block to h6', () {
      var state = _stateWithText('');
      for (var i = 0; i < 6; i++) {
        final next = controller.handleKeyDown(
          state,
          const KeyDownEvent(
            timeStamp: Duration.zero,
            physicalKey: PhysicalKeyboardKey.digit3,
            logicalKey: LogicalKeyboardKey.numberSign,
            character: '#',
          ),
          enableEditing: true,
          pressedKeys: <LogicalKeyboardKey>{},
        );
        expect(next, isNotNull);
        state = next!;
      }

      final afterSpace = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          character: ' ',
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );
      expect(afterSpace, isNotNull);
      final block = afterSpace!.document.blockById('b1');
      expect(block.type, BlockType.heading);
      expect(block.headingLevel, 6);
      expect(block.plainText, '###### ');
    });

    test('tab and shift+tab indent/outdent bullet list item', () {
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

      final indented = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );
      expect(indented, isNotNull);
      expect(indented!.document.blockById('b1').plainText, '  - item');

      final outdented = controller.handleKeyDown(
        indented,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{LogicalKeyboardKey.shiftLeft},
      );
      expect(outdented, isNotNull);
      expect(outdented!.document.blockById('b1').plainText, '- item');
    });

    test('tab and shift+tab indent/outdent ordered list item', () {
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
          const RichTextPosition(blockId: 'b1', offset: 3),
        ),
      );

      final indented = controller.handleKeyDown(
        state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{},
      );
      expect(indented, isNotNull);
      expect(indented!.document.blockById('b1').plainText, '  1. item');

      final outdented = controller.handleKeyDown(
        indented,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
        ),
        enableEditing: true,
        pressedKeys: <LogicalKeyboardKey>{LogicalKeyboardKey.shiftLeft},
      );
      expect(outdented, isNotNull);
      expect(outdented!.document.blockById('b1').plainText, '1. item');
    });
  });
}

RichDocumentEditorState _stateWithText(String text) {
  return RichDocumentEditorState(
    document: RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: text)],
    ),
    selection: RichSelection.collapsed(
      const RichTextPosition(blockId: 'b1', offset: 0),
    ),
  );
}
