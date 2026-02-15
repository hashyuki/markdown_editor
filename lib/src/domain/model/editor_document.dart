import 'editor_content.dart';

class EditorDocument {
  const EditorDocument({required this.content});

  factory EditorDocument.empty() =>
      const EditorDocument(content: EditorContent(''));

  final EditorContent content;

  EditorDocument copyWith({EditorContent? content}) {
    return EditorDocument(content: content ?? this.content);
  }
}
