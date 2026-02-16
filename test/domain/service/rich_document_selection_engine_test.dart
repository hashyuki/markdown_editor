import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/rich_document.dart';
import 'package:markdown_editor/src/domain/model/rich_document_selection.dart';
import 'package:markdown_editor/src/domain/service/rich_document_selection_engine.dart';

void main() {
  group('RichDocumentSelectionEngine', () {
    late RichDocumentSelectionEngine engine;
    late RichDocument document;

    setUp(() {
      engine = const RichDocumentSelectionEngine();
      document = RichDocument(
        blocks: <BlockNode>[
          BlockNode.paragraph(id: 'b1', text: 'abc'),
          BlockNode.paragraph(id: 'b2', text: 'xy'),
          BlockNode.paragraph(id: 'b3', text: 'hello'),
        ],
      );
    });

    test('moveLeft crosses to previous block end', () {
      final selection = RichSelection.collapsed(
        const RichTextPosition(blockId: 'b2', offset: 0),
      );

      final result = engine.moveLeft(document, selection);

      expect(result.base.blockId, 'b1');
      expect(result.base.offset, 3);
      expect(result.isCollapsed, isTrue);
    });

    test('moveRight crosses to next block start', () {
      final selection = RichSelection.collapsed(
        const RichTextPosition(blockId: 'b2', offset: 2),
      );

      final result = engine.moveRight(document, selection);

      expect(result.base.blockId, 'b3');
      expect(result.base.offset, 0);
      expect(result.isCollapsed, isTrue);
    });

    test('moveRight collapses expanded selection to end', () {
      const selection = RichSelection(
        base: RichTextPosition(blockId: 'b1', offset: 1),
        extent: RichTextPosition(blockId: 'b2', offset: 1),
      );

      final result = engine.moveRight(document, selection);

      expect(result.base.blockId, 'b2');
      expect(result.base.offset, 1);
      expect(result.isCollapsed, isTrue);
    });

    test('moveLeft collapses expanded reversed selection to start', () {
      const selection = RichSelection(
        base: RichTextPosition(blockId: 'b2', offset: 1),
        extent: RichTextPosition(blockId: 'b1', offset: 1),
      );

      final result = engine.moveLeft(document, selection);

      expect(result.base.blockId, 'b1');
      expect(result.base.offset, 1);
      expect(result.isCollapsed, isTrue);
    });

    test('moveDown keeps preferred column and clamps by line length', () {
      final selection = RichSelection.collapsed(
        const RichTextPosition(blockId: 'b1', offset: 2),
      );

      final step1 = engine.moveDown(document, selection);
      expect(step1.selection.extent.blockId, 'b2');
      expect(step1.selection.extent.offset, 2);
      expect(step1.preferredColumn, 2);

      final step2 = engine.moveDown(
        document,
        step1.selection,
        preferredColumn: step1.preferredColumn,
      );
      expect(step2.selection.extent.blockId, 'b3');
      expect(step2.selection.extent.offset, 2);
    });

    test('moveUp expands when shift behavior is requested', () {
      final selection = RichSelection.collapsed(
        const RichTextPosition(blockId: 'b2', offset: 1),
      );

      final result = engine.moveUp(document, selection, expand: true);

      expect(result.selection.base.blockId, 'b2');
      expect(result.selection.base.offset, 1);
      expect(result.selection.extent.blockId, 'b1');
      expect(result.selection.extent.offset, 1);
      expect(result.selection.isCollapsed, isFalse);
    });

    test('clampSelection normalizes invalid block/offset values', () {
      const selection = RichSelection(
        base: RichTextPosition(blockId: 'missing', offset: 99),
        extent: RichTextPosition(blockId: 'b3', offset: 99),
      );

      final clamped = engine.clampSelection(document, selection);

      expect(clamped.base.blockId, 'b1');
      expect(clamped.base.offset, 0);
      expect(clamped.extent.blockId, 'b3');
      expect(clamped.extent.offset, 5);
    });
  });
}
