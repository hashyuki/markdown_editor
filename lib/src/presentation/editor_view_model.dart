import 'package:flutter/foundation.dart';

import '../application/use_case/load_editor_document_use_case.dart';
import '../application/use_case/update_editor_document_use_case.dart';
import '../domain/model/editor_document.dart';

class EditorViewModel extends ChangeNotifier {
  EditorViewModel({
    required LoadEditorDocumentUseCase loadUseCase,
    required UpdateEditorDocumentUseCase updateUseCase,
  }) : _loadUseCase = loadUseCase,
       _updateUseCase = updateUseCase;

  final LoadEditorDocumentUseCase _loadUseCase;
  final UpdateEditorDocumentUseCase _updateUseCase;

  EditorDocument _document = EditorDocument.empty();

  EditorDocument get document => _document;
  String get text => _document.content.value;

  void initialize() {
    _document = _loadUseCase();
    notifyListeners();
  }

  void onTextChanged(String value) {
    _document = _updateUseCase(value);
    notifyListeners();
  }
}
