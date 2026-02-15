import '../model/editor_document.dart';

abstract interface class EditorRepository {
  EditorDocument load();

  void save(EditorDocument document);
}
