import 'editor_line.dart';

class EditorContent {
  const EditorContent(this.value);

  final String value;

  bool get isEmpty => value.isEmpty;

  List<EditorLine> get lines =>
      value.split('\n').map(EditorLine.new).toList(growable: false);
}
