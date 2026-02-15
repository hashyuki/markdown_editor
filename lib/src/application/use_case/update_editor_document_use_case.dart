import '../../domain/model/editor_content.dart';
import '../../domain/model/editor_document.dart';
import '../../domain/repository/editor_repository.dart';

class UpdateEditorDocumentUseCase {
  const UpdateEditorDocumentUseCase(this._repository);

  final EditorRepository _repository;

  EditorDocument call(String rawText) {
    final document = EditorDocument(content: EditorContent(rawText));
    _repository.save(document);
    return document;
  }
}
