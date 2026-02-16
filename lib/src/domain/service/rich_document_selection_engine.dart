import '../model/rich_document.dart';
import '../model/rich_document_selection.dart';

class SelectionMoveResult {
  const SelectionMoveResult({
    required this.selection,
    required this.preferredColumn,
  });

  final RichSelection selection;
  final int preferredColumn;
}

abstract interface class RichSelectionEngine {
  RichSelection clampSelection(RichDocument document, RichSelection selection);

  RichSelection selectAll(RichDocument document);

  RichSelection moveLeft(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  });

  RichSelection moveRight(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  });

  SelectionMoveResult moveUp(
    RichDocument document,
    RichSelection selection, {
    int? preferredColumn,
    bool expand = false,
  });

  SelectionMoveResult moveDown(
    RichDocument document,
    RichSelection selection, {
    int? preferredColumn,
    bool expand = false,
  });

  RichSelection moveToLineStart(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  });

  RichSelection moveToLineEnd(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  });
}

class RichDocumentSelectionEngine implements RichSelectionEngine {
  const RichDocumentSelectionEngine();

  @override
  RichSelection clampSelection(RichDocument document, RichSelection selection) {
    return RichSelection(
      base: _clampPosition(document, selection.base),
      extent: _clampPosition(document, selection.extent),
    );
  }

  @override
  RichSelection selectAll(RichDocument document) {
    final first = document.blocks.first;
    final last = document.blocks.last;
    return RichSelection(
      base: RichTextPosition(blockId: first.id, offset: 0),
      extent: RichTextPosition(blockId: last.id, offset: last.textLength),
    );
  }

  @override
  RichSelection moveLeft(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    if (!expand && !clamped.isCollapsed) {
      final normalized = _normalize(document, clamped);
      return RichSelection.collapsed(normalized.start);
    }

    final nextExtent = _moveLeftOnce(document, clamped.extent);
    return _nextSelection(clamped, nextExtent: nextExtent, expand: expand);
  }

  @override
  RichSelection moveRight(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    if (!expand && !clamped.isCollapsed) {
      final normalized = _normalize(document, clamped);
      return RichSelection.collapsed(normalized.end);
    }

    final nextExtent = _moveRightOnce(document, clamped.extent);
    return _nextSelection(clamped, nextExtent: nextExtent, expand: expand);
  }

  @override
  SelectionMoveResult moveUp(
    RichDocument document,
    RichSelection selection, {
    int? preferredColumn,
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    final currentIndex = document.indexOfBlock(clamped.extent.blockId);
    if (currentIndex <= 0) {
      return SelectionMoveResult(
        selection: clamped,
        preferredColumn: preferredColumn ?? clamped.extent.offset,
      );
    }

    final column = preferredColumn ?? clamped.extent.offset;
    final previous = document.blocks[currentIndex - 1];
    final nextExtent = RichTextPosition(
      blockId: previous.id,
      offset: column.clamp(0, previous.textLength),
    );
    return SelectionMoveResult(
      selection: _nextSelection(
        clamped,
        nextExtent: nextExtent,
        expand: expand,
      ),
      preferredColumn: column,
    );
  }

  @override
  SelectionMoveResult moveDown(
    RichDocument document,
    RichSelection selection, {
    int? preferredColumn,
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    final currentIndex = document.indexOfBlock(clamped.extent.blockId);
    if (currentIndex == -1 || currentIndex >= document.blocks.length - 1) {
      return SelectionMoveResult(
        selection: clamped,
        preferredColumn: preferredColumn ?? clamped.extent.offset,
      );
    }

    final column = preferredColumn ?? clamped.extent.offset;
    final next = document.blocks[currentIndex + 1];
    final nextExtent = RichTextPosition(
      blockId: next.id,
      offset: column.clamp(0, next.textLength),
    );
    return SelectionMoveResult(
      selection: _nextSelection(
        clamped,
        nextExtent: nextExtent,
        expand: expand,
      ),
      preferredColumn: column,
    );
  }

  @override
  RichSelection moveToLineStart(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    final nextExtent = RichTextPosition(
      blockId: clamped.extent.blockId,
      offset: 0,
    );
    return _nextSelection(clamped, nextExtent: nextExtent, expand: expand);
  }

  @override
  RichSelection moveToLineEnd(
    RichDocument document,
    RichSelection selection, {
    bool expand = false,
  }) {
    final clamped = clampSelection(document, selection);
    final block = document.blockById(clamped.extent.blockId);
    final nextExtent = RichTextPosition(
      blockId: clamped.extent.blockId,
      offset: block.textLength,
    );
    return _nextSelection(clamped, nextExtent: nextExtent, expand: expand);
  }

  RichSelection _nextSelection(
    RichSelection current, {
    required RichTextPosition nextExtent,
    required bool expand,
  }) {
    if (expand) {
      return RichSelection(base: current.base, extent: nextExtent);
    }
    return RichSelection.collapsed(nextExtent);
  }

  RichTextPosition _moveLeftOnce(
    RichDocument document,
    RichTextPosition current,
  ) {
    if (current.offset > 0) {
      return RichTextPosition(
        blockId: current.blockId,
        offset: current.offset - 1,
      );
    }

    final blockIndex = document.indexOfBlock(current.blockId);
    if (blockIndex <= 0) {
      return RichTextPosition(blockId: current.blockId, offset: 0);
    }

    final previous = document.blocks[blockIndex - 1];
    return RichTextPosition(blockId: previous.id, offset: previous.textLength);
  }

  RichTextPosition _moveRightOnce(
    RichDocument document,
    RichTextPosition current,
  ) {
    final block = document.blockById(current.blockId);
    if (current.offset < block.textLength) {
      return RichTextPosition(
        blockId: current.blockId,
        offset: current.offset + 1,
      );
    }

    final blockIndex = document.indexOfBlock(current.blockId);
    if (blockIndex == -1 || blockIndex >= document.blocks.length - 1) {
      return RichTextPosition(
        blockId: current.blockId,
        offset: block.textLength,
      );
    }

    final next = document.blocks[blockIndex + 1];
    return RichTextPosition(blockId: next.id, offset: 0);
  }

  RichTextPosition _clampPosition(
    RichDocument document,
    RichTextPosition position,
  ) {
    final blockIndex = document.indexOfBlock(position.blockId);
    if (blockIndex == -1) {
      final first = document.blocks.first;
      return RichTextPosition(blockId: first.id, offset: 0);
    }

    final block = document.blocks[blockIndex];
    return RichTextPosition(
      blockId: block.id,
      offset: position.offset.clamp(0, block.textLength),
    );
  }

  _SelectionBounds _normalize(RichDocument document, RichSelection selection) {
    final compare = _compare(document, selection.base, selection.extent);
    if (compare <= 0) {
      return _SelectionBounds(start: selection.base, end: selection.extent);
    }
    return _SelectionBounds(start: selection.extent, end: selection.base);
  }

  int _compare(RichDocument document, RichTextPosition a, RichTextPosition b) {
    final blockIndexA = document.indexOfBlock(a.blockId);
    final blockIndexB = document.indexOfBlock(b.blockId);
    if (blockIndexA != blockIndexB) {
      return blockIndexA.compareTo(blockIndexB);
    }
    return a.offset.compareTo(b.offset);
  }
}

class _SelectionBounds {
  const _SelectionBounds({required this.start, required this.end});

  final RichTextPosition start;
  final RichTextPosition end;
}
