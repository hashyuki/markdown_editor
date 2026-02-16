import '../../domain/model/rich_document.dart';
import '../../domain/model/rich_document_selection.dart';
import '../../domain/service/block_id_allocator.dart';
import '../../domain/service/markdown_block_syntax_service.dart';
import '../../domain/service/rich_document_selection_engine.dart';
import '../../domain/service/rich_document_transaction.dart';

class RichDocumentEditorState {
  const RichDocumentEditorState({
    required this.document,
    required this.selection,
    this.preferredColumn,
  });

  final RichDocument document;
  final RichSelection selection;
  final int? preferredColumn;

  RichDocumentEditorState copyWith({
    RichDocument? document,
    RichSelection? selection,
    int? preferredColumn,
    bool clearPreferredColumn = false,
  }) {
    return RichDocumentEditorState(
      document: document ?? this.document,
      selection: selection ?? this.selection,
      preferredColumn: clearPreferredColumn
          ? null
          : (preferredColumn ?? this.preferredColumn),
    );
  }
}

class EditRichDocumentUseCase {
  const EditRichDocumentUseCase({
    this.selectionEngine = const RichDocumentSelectionEngine(),
    this.syntaxService = const MarkdownBlockSyntaxService(),
    this.blockIdAllocator = const BlockIdAllocator(),
  });

  final RichDocumentSelectionEngine selectionEngine;
  final MarkdownBlockSyntaxService syntaxService;
  final BlockIdAllocator blockIdAllocator;

  RichDocumentEditorState normalize(RichDocumentEditorState state) {
    return state.copyWith(
      selection: selectionEngine.clampSelection(
        state.document,
        state.selection,
      ),
    );
  }

  RichDocumentEditorState moveLeft(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    return normalized.copyWith(
      selection: selectionEngine.moveLeft(
        normalized.document,
        normalized.selection,
        expand: expand,
      ),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState moveRight(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    return normalized.copyWith(
      selection: selectionEngine.moveRight(
        normalized.document,
        normalized.selection,
        expand: expand,
      ),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState moveUp(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    final result = selectionEngine.moveUp(
      normalized.document,
      normalized.selection,
      preferredColumn: normalized.preferredColumn,
      expand: expand,
    );
    return normalized.copyWith(
      selection: result.selection,
      preferredColumn: result.preferredColumn,
    );
  }

  RichDocumentEditorState moveDown(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    final result = selectionEngine.moveDown(
      normalized.document,
      normalized.selection,
      preferredColumn: normalized.preferredColumn,
      expand: expand,
    );
    return normalized.copyWith(
      selection: result.selection,
      preferredColumn: result.preferredColumn,
    );
  }

  RichDocumentEditorState moveToLineStart(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    return normalized.copyWith(
      selection: selectionEngine.moveToLineStart(
        normalized.document,
        normalized.selection,
        expand: expand,
      ),
      preferredColumn: 0,
    );
  }

  RichDocumentEditorState moveToLineEnd(
    RichDocumentEditorState state, {
    required bool expand,
  }) {
    final normalized = normalize(state);
    final nextSelection = selectionEngine.moveToLineEnd(
      normalized.document,
      normalized.selection,
      expand: expand,
    );
    return normalized.copyWith(
      selection: nextSelection,
      preferredColumn: nextSelection.extent.offset,
    );
  }

  RichDocumentEditorState selectAll(RichDocumentEditorState state) {
    final normalized = normalize(state);
    return normalized.copyWith(
      selection: selectionEngine.selectAll(normalized.document),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState deleteSelection(RichDocumentEditorState state) {
    final normalized = normalize(state);
    final next = _deleteSelectionIfNeeded(normalized);
    return next.copyWith(clearPreferredColumn: true);
  }

  String selectedPlainText(RichDocumentEditorState state) {
    final normalized = normalize(state);
    if (normalized.selection.isCollapsed) {
      final caret = normalized.selection.extent;
      final block = normalized.document.blockById(caret.blockId);
      return block.plainText;
    }
    final bounds = _normalizeSelection(
      normalized.document,
      normalized.selection,
    );
    final startIndex = normalized.document.indexOfBlock(bounds.start.blockId);
    final endIndex = normalized.document.indexOfBlock(bounds.end.blockId);
    if (startIndex == -1 || endIndex == -1) {
      return '';
    }
    if (startIndex == endIndex) {
      final text = normalized.document
          .blockById(bounds.start.blockId)
          .plainText;
      return text.substring(bounds.start.offset, bounds.end.offset);
    }

    final segments = <String>[];
    for (var index = startIndex; index <= endIndex; index++) {
      final block = normalized.document.blocks[index];
      if (index == startIndex) {
        segments.add(block.plainText.substring(bounds.start.offset));
        continue;
      }
      if (index == endIndex) {
        segments.add(block.plainText.substring(0, bounds.end.offset));
        continue;
      }
      segments.add(block.plainText);
    }
    return segments.join('\n');
  }

  RichDocumentEditorState pastePlainText(
    RichDocumentEditorState state,
    String text,
  ) {
    if (text.isEmpty) {
      return normalize(state);
    }
    final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var next = normalize(state);
    final lines = normalizedText.split('\n');
    if (lines.isEmpty) {
      return next;
    }
    final caret = next.selection.extent;
    final currentBlock = next.document.blockById(caret.blockId);
    if (_isMarkerOnlyListBlock(currentBlock) &&
        _isListLine(lines.first) &&
        caret.offset == currentBlock.textLength) {
      var document = next.document.replaceBlock(
        currentBlock.copyWith(inlines: _plainInline(lines.first)),
      );
      document = syntaxService.synchronizeBlockSyntaxFromText(
        document,
        currentBlock.id,
      );
      next = next.copyWith(
        document: document,
        selection: RichSelection.collapsed(
          RichTextPosition(
            blockId: currentBlock.id,
            offset: lines.first.length,
          ),
        ),
        preferredColumn: lines.first.length,
      );
    } else if (lines.first.isNotEmpty) {
      next = insertText(next, lines.first);
    }
    for (var index = 1; index < lines.length; index++) {
      next = _insertRawNewLine(next);
      final line = lines[index];
      if (line.isNotEmpty) {
        next = insertText(next, line);
      }
    }
    return next;
  }

  bool _isMarkerOnlyListBlock(BlockNode block) {
    return syntaxService.isMarkerOnlyListBlock(block);
  }

  bool _isListLine(String line) {
    return syntaxService.isListLine(line);
  }

  RichDocumentEditorState _insertRawNewLine(RichDocumentEditorState state) {
    final editable = _deleteSelectionIfNeeded(normalize(state));
    final caret = editable.selection.extent;
    final currentBlock = editable.document.blockById(caret.blockId);
    final newBlockId = blockIdAllocator.nextBlockId(editable.document);
    var nextDocument = SplitBlockCommand(
      blockId: caret.blockId,
      offset: caret.offset,
      newBlockId: newBlockId,
    ).apply(editable.document);
    if (currentBlock.type == BlockType.heading) {
      nextDocument = SetBlockTypeCommand(
        blockId: newBlockId,
        type: BlockType.paragraph,
      ).apply(nextDocument);
    }
    return editable.copyWith(
      document: nextDocument,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: newBlockId, offset: 0),
      ),
      preferredColumn: 0,
    );
  }

  RichDocumentEditorState indentListItem(RichDocumentEditorState state) {
    final normalized = normalize(state);
    final caret = normalized.selection.extent;
    final block = normalized.document.blockById(caret.blockId);
    if (block.type != BlockType.bulletListItem &&
        block.type != BlockType.orderedListItem) {
      return normalized;
    }

    final nextIndent = block.indent + 1;
    final updated = block.type == BlockType.bulletListItem
        ? syntaxService.replaceBulletIndentText(block.plainText, nextIndent)
        : syntaxService.replaceOrderedIndentText(block.plainText, nextIndent);
    final document = normalized.document.replaceBlock(
      block.copyWith(
        inlines: _plainInline(updated.text),
        indent: updated.indent,
      ),
    );
    final newOffset = _shiftCaretByIndentChange(
      block: block,
      previousOffset: caret.offset,
      nextIndent: nextIndent,
    );
    return normalized.copyWith(
      document: document,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: block.id, offset: newOffset),
      ),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState outdentListItem(RichDocumentEditorState state) {
    final normalized = normalize(state);
    final caret = normalized.selection.extent;
    final block = normalized.document.blockById(caret.blockId);
    if (block.type != BlockType.bulletListItem &&
        block.type != BlockType.orderedListItem) {
      return normalized;
    }

    final nextIndent = block.indent > 0 ? block.indent - 1 : 0;
    final updated = block.type == BlockType.bulletListItem
        ? syntaxService.replaceBulletIndentText(block.plainText, nextIndent)
        : syntaxService.replaceOrderedIndentText(block.plainText, nextIndent);
    final document = normalized.document.replaceBlock(
      block.copyWith(
        inlines: _plainInline(updated.text),
        indent: updated.indent,
      ),
    );
    final newOffset = _shiftCaretByIndentChange(
      block: block,
      previousOffset: caret.offset,
      nextIndent: nextIndent,
    );
    return normalized.copyWith(
      document: document,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: block.id, offset: newOffset),
      ),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState insertText(
    RichDocumentEditorState state,
    String text,
  ) {
    if (text.isEmpty) {
      return state;
    }
    final editable = _deleteSelectionIfNeeded(normalize(state));
    final caret = editable.selection.extent;
    final insertedDocument = InsertTextCommand(
      blockId: caret.blockId,
      offset: caret.offset,
      text: text,
    ).apply(editable.document);
    final insertedSelection = RichSelection.collapsed(
      RichTextPosition(
        blockId: caret.blockId,
        offset: caret.offset + text.length,
      ),
    );
    final synchronizedDocument = syntaxService.synchronizeBlockSyntaxFromText(
      insertedDocument,
      caret.blockId,
    );
    final normalizedDocument = _ensureDefaultEmptyParagraph(
      synchronizedDocument,
    );
    return editable.copyWith(
      document: normalizedDocument,
      selection: insertedSelection,
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState insertNewLine(RichDocumentEditorState state) {
    final editable = _deleteSelectionIfNeeded(normalize(state));
    final caret = editable.selection.extent;
    final currentBlock = editable.document.blockById(caret.blockId);
    if (currentBlock.type == BlockType.bulletListItem) {
      return _insertNewLineInBulletItem(editable, currentBlock, caret);
    }
    if (currentBlock.type == BlockType.orderedListItem) {
      return _insertNewLineInOrderedItem(editable, currentBlock, caret);
    }
    final newBlockId = blockIdAllocator.nextBlockId(editable.document);
    var nextDocument = SplitBlockCommand(
      blockId: caret.blockId,
      offset: caret.offset,
      newBlockId: newBlockId,
    ).apply(editable.document);
    if (currentBlock.type == BlockType.heading) {
      nextDocument = SetBlockTypeCommand(
        blockId: newBlockId,
        type: BlockType.paragraph,
      ).apply(nextDocument);
    }
    return editable.copyWith(
      document: nextDocument,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: newBlockId, offset: 0),
      ),
      preferredColumn: 0,
    );
  }

  RichDocumentEditorState backspace(RichDocumentEditorState state) {
    final editable = _deleteSelectionIfNeeded(normalize(state));
    final caret = editable.selection.extent;
    if (caret.offset > 0) {
      final updated = DeleteTextRangeCommand(
        blockId: caret.blockId,
        start: caret.offset - 1,
        end: caret.offset,
      ).apply(editable.document);
      final synchronizedDocument = syntaxService.synchronizeBlockSyntaxFromText(
        updated,
        caret.blockId,
      );
      final normalizedDocument = _ensureDefaultEmptyParagraph(
        synchronizedDocument,
      );
      return editable.copyWith(
        document: normalizedDocument,
        selection: RichSelection.collapsed(
          RichTextPosition(blockId: caret.blockId, offset: caret.offset - 1),
        ),
        clearPreferredColumn: true,
      );
    }

    final blockIndex = editable.document.indexOfBlock(caret.blockId);
    if (blockIndex <= 0) {
      return editable;
    }
    final previous = editable.document.blocks[blockIndex - 1];
    final merged = MergeWithPreviousBlockCommand(
      blockId: caret.blockId,
    ).apply(editable.document);
    final synchronizedDocument = syntaxService.synchronizeBlockSyntaxFromText(
      merged,
      previous.id,
    );
    final normalizedDocument = _ensureDefaultEmptyParagraph(
      synchronizedDocument,
    );
    return editable.copyWith(
      document: normalizedDocument,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: previous.id, offset: previous.textLength),
      ),
      clearPreferredColumn: true,
    );
  }

  RichDocumentEditorState _deleteSelectionIfNeeded(
    RichDocumentEditorState state,
  ) {
    final selection = state.selection;
    if (selection.isCollapsed) {
      return state;
    }

    final normalized = _normalizeSelection(state.document, selection);
    final start = normalized.start;
    final end = normalized.end;
    if (start.blockId == end.blockId) {
      final updated = DeleteTextRangeCommand(
        blockId: start.blockId,
        start: start.offset,
        end: end.offset,
      ).apply(state.document);
      final synchronizedDocument = syntaxService.synchronizeBlockSyntaxFromText(
        updated,
        start.blockId,
      );
      final normalizedDocument = _ensureDefaultEmptyParagraph(
        synchronizedDocument,
      );
      return state.copyWith(
        document: normalizedDocument,
        selection: RichSelection.collapsed(start),
      );
    }

    var updated = DeleteTextRangeCommand(
      blockId: start.blockId,
      start: start.offset,
      end: state.document.blockById(start.blockId).textLength,
    ).apply(state.document);

    updated = DeleteTextRangeCommand(
      blockId: end.blockId,
      start: 0,
      end: end.offset,
    ).apply(updated);

    while (true) {
      final startIndex = updated.indexOfBlock(start.blockId);
      final endIndex = updated.indexOfBlock(end.blockId);
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex + 1) {
        break;
      }
      updated = updated.removeBlockById(updated.blocks[startIndex + 1].id);
    }

    updated = MergeWithPreviousBlockCommand(
      blockId: end.blockId,
    ).apply(updated);
    final synchronizedDocument = syntaxService.synchronizeBlockSyntaxFromText(
      updated,
      start.blockId,
    );
    final normalizedDocument = _ensureDefaultEmptyParagraph(
      synchronizedDocument,
    );
    return state.copyWith(
      document: normalizedDocument,
      selection: RichSelection.collapsed(start),
    );
  }

  RichDocument _ensureDefaultEmptyParagraph(RichDocument document) {
    if (document.blocks.length != 1) {
      return document;
    }
    final block = document.blocks.first;
    if (block.textLength != 0) {
      return document;
    }
    if (block.type == BlockType.paragraph &&
        block.headingLevel == null &&
        block.indent == 0 &&
        block.codeLanguage == null) {
      return document;
    }
    return document.replaceBlock(
      block.copyWith(
        type: BlockType.paragraph,
        clearHeadingLevel: true,
        indent: 0,
        clearCodeLanguage: true,
      ),
    );
  }

  RichDocumentEditorState _insertNewLineInBulletItem(
    RichDocumentEditorState editable,
    BlockNode currentBlock,
    RichTextPosition caret,
  ) {
    final text = currentBlock.plainText;
    final isEmptyItem = syntaxService.isBulletMarkerOnlyText(text);
    if (isEmptyItem) {
      if (currentBlock.indent > 0) {
        final nextIndent = currentBlock.indent - 1;
        final replaced = syntaxService.replaceBulletIndentText(
          text,
          nextIndent,
        );
        final document = editable.document.replaceBlock(
          currentBlock.copyWith(
            inlines: _plainInline(replaced.text),
            indent: nextIndent,
          ),
        );
        final caretOffset = syntaxService.bulletPrefixLength(nextIndent);
        return editable.copyWith(
          document: document,
          selection: RichSelection.collapsed(
            RichTextPosition(blockId: currentBlock.id, offset: caretOffset),
          ),
          preferredColumn: caretOffset,
        );
      }
      final document = editable.document.replaceBlock(
        currentBlock.copyWith(
          type: BlockType.paragraph,
          inlines: const <InlineText>[],
          indent: 0,
        ),
      );
      return editable.copyWith(
        document: document,
        selection: RichSelection.collapsed(
          RichTextPosition(blockId: currentBlock.id, offset: 0),
        ),
        preferredColumn: 0,
      );
    }

    final newBlockId = blockIdAllocator.nextBlockId(editable.document);
    var nextDocument = SplitBlockCommand(
      blockId: currentBlock.id,
      offset: caret.offset,
      newBlockId: newBlockId,
    ).apply(editable.document);
    final newBlock = nextDocument.blockById(newBlockId);
    final marker = syntaxService.bulletMarker(text) ?? '-';
    final prefix = '${syntaxService.indentSpaces(currentBlock.indent)}$marker ';
    final nextText = '$prefix${newBlock.plainText}';
    nextDocument = nextDocument.replaceBlock(
      newBlock.copyWith(
        type: BlockType.bulletListItem,
        inlines: _plainInline(nextText),
        indent: currentBlock.indent,
      ),
    );
    final caretOffset = prefix.length;
    return editable.copyWith(
      document: nextDocument,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: newBlockId, offset: caretOffset),
      ),
      preferredColumn: caretOffset,
    );
  }

  RichDocumentEditorState _insertNewLineInOrderedItem(
    RichDocumentEditorState editable,
    BlockNode currentBlock,
    RichTextPosition caret,
  ) {
    final text = currentBlock.plainText;
    final isEmptyItem = syntaxService.isOrderedMarkerOnlyText(text);
    if (isEmptyItem) {
      if (currentBlock.indent > 0) {
        final nextIndent = currentBlock.indent - 1;
        final replaced = syntaxService.replaceOrderedIndentText(
          text,
          nextIndent,
        );
        final document = editable.document.replaceBlock(
          currentBlock.copyWith(
            inlines: _plainInline(replaced.text),
            indent: nextIndent,
          ),
        );
        final caretOffset = syntaxService.orderedPrefixLength(nextIndent, 1);
        return editable.copyWith(
          document: document,
          selection: RichSelection.collapsed(
            RichTextPosition(blockId: currentBlock.id, offset: caretOffset),
          ),
          preferredColumn: caretOffset,
        );
      }
      final document = editable.document.replaceBlock(
        currentBlock.copyWith(
          type: BlockType.paragraph,
          inlines: const <InlineText>[],
          indent: 0,
        ),
      );
      return editable.copyWith(
        document: document,
        selection: RichSelection.collapsed(
          RichTextPosition(blockId: currentBlock.id, offset: 0),
        ),
        preferredColumn: 0,
      );
    }

    final newBlockId = blockIdAllocator.nextBlockId(editable.document);
    var nextDocument = SplitBlockCommand(
      blockId: currentBlock.id,
      offset: caret.offset,
      newBlockId: newBlockId,
    ).apply(editable.document);
    final newBlock = nextDocument.blockById(newBlockId);
    final marker = syntaxService.orderedMarker(text) ?? 1;
    final prefix =
        '${syntaxService.indentSpaces(currentBlock.indent)}$marker. ';
    final nextText = '$prefix${newBlock.plainText}';
    nextDocument = nextDocument.replaceBlock(
      newBlock.copyWith(
        type: BlockType.orderedListItem,
        inlines: _plainInline(nextText),
        indent: currentBlock.indent,
      ),
    );
    final caretOffset = prefix.length;
    return editable.copyWith(
      document: nextDocument,
      selection: RichSelection.collapsed(
        RichTextPosition(blockId: newBlockId, offset: caretOffset),
      ),
      preferredColumn: caretOffset,
    );
  }

  int _shiftCaretByIndentChange({
    required BlockNode block,
    required int previousOffset,
    required int nextIndent,
  }) {
    final currentPrefix = _listPrefixLength(block, block.indent);
    final nextPrefix = _listPrefixLength(block, nextIndent);
    if (previousOffset <= currentPrefix) {
      return nextPrefix;
    }
    final contentOffset = previousOffset - currentPrefix;
    return nextPrefix + contentOffset;
  }

  int _listPrefixLength(BlockNode block, int indent) {
    if (block.type == BlockType.orderedListItem) {
      return syntaxService.orderedPrefixLength(
        indent,
        syntaxService.orderedMarker(block.plainText) ?? 1,
      );
    }
    return syntaxService.bulletPrefixLength(indent);
  }

  List<InlineText> _plainInline(String text) {
    if (text.isEmpty) {
      return const <InlineText>[];
    }
    return <InlineText>[InlineText(text: text)];
  }

  _NormalizedSelection _normalizeSelection(
    RichDocument document,
    RichSelection selection,
  ) {
    final baseIndex = document.indexOfBlock(selection.base.blockId);
    final extentIndex = document.indexOfBlock(selection.extent.blockId);
    final isBaseFirst =
        baseIndex < extentIndex ||
        (baseIndex == extentIndex &&
            selection.base.offset <= selection.extent.offset);
    return isBaseFirst
        ? _NormalizedSelection(start: selection.base, end: selection.extent)
        : _NormalizedSelection(start: selection.extent, end: selection.base);
  }
}

class _NormalizedSelection {
  const _NormalizedSelection({required this.start, required this.end});

  final RichTextPosition start;
  final RichTextPosition end;
}
