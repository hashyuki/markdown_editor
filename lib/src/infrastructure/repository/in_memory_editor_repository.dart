import '../../domain/model/editor_document.dart';
import '../../domain/repository/editor_repository.dart';

class InMemoryEditorRepository implements EditorRepository {
  EditorDocument _current = EditorDocument.empty();

  @override
  EditorDocument load() {
    return _current;
  }

  @override
  void save(EditorDocument document) {
    _current = document;
  }
}
