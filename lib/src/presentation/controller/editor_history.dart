import '../../application/use_case/edit_rich_document_use_case.dart';
import '../../domain/model/rich_document.dart';
import '../../domain/model/rich_document_selection.dart';

class EditorHistory {
  EditorHistory({this.maxEntries = 200});

  final int maxEntries;
  final List<_HistorySnapshot> _undoStack = <_HistorySnapshot>[];
  final List<_HistorySnapshot> _redoStack = <_HistorySnapshot>[];

  void reset() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void pushIfDocumentChanged({
    required RichDocumentEditorState previous,
    required RichDocumentEditorState next,
  }) {
    if (previous.document == next.document) {
      return;
    }
    final snapshot = _HistorySnapshot(
      document: previous.document,
      selection: previous.selection,
    );
    if (_undoStack.isNotEmpty && _undoStack.last.sameAs(snapshot)) {
      return;
    }
    _undoStack.add(snapshot);
    if (_undoStack.length > maxEntries) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  RichDocumentEditorState? undo(RichDocumentEditorState current) {
    if (_undoStack.isEmpty) {
      return null;
    }
    final previous = _undoStack.removeLast();
    _redoStack.add(
      _HistorySnapshot(
        document: current.document,
        selection: current.selection,
      ),
    );
    return current.copyWith(
      document: previous.document,
      selection: previous.selection,
    );
  }

  RichDocumentEditorState? redo(RichDocumentEditorState current) {
    if (_redoStack.isEmpty) {
      return null;
    }
    final next = _redoStack.removeLast();
    _undoStack.add(
      _HistorySnapshot(
        document: current.document,
        selection: current.selection,
      ),
    );
    return current.copyWith(document: next.document, selection: next.selection);
  }
}

class _HistorySnapshot {
  const _HistorySnapshot({required this.document, required this.selection});

  final RichDocument document;
  final RichSelection selection;

  bool sameAs(_HistorySnapshot other) {
    return document == other.document &&
        selection.base.blockId == other.selection.base.blockId &&
        selection.base.offset == other.selection.base.offset &&
        selection.extent.blockId == other.selection.extent.blockId &&
        selection.extent.offset == other.selection.extent.offset;
  }
}
