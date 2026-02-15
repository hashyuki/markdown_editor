import '../../domain/model/editor_document.dart';
import '../../domain/repository/editor_repository.dart';

class LoadEditorDocumentUseCase {
  const LoadEditorDocumentUseCase(this._repository);

  final EditorRepository _repository;

  EditorDocument call() {
    return _repository.load();
  }
}
