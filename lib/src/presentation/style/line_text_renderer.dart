import '../../domain/model/line_syntax.dart';

abstract interface class LineTextRenderer {
  const LineTextRenderer();

  String render({required String lineText, required LineSyntax syntax});
}

class MarkdownLineTextRenderer implements LineTextRenderer {
  const MarkdownLineTextRenderer();

  @override
  String render({required String lineText, required LineSyntax syntax}) {
    final list = syntax.list;
    if (list == null) {
      return lineText;
    }
    switch (list.type) {
      case ListType.unordered:
        final markerIndex = list.indent;
        if (markerIndex < 0 || markerIndex >= lineText.length) {
          return lineText;
        }
        return lineText.replaceRange(markerIndex, markerIndex + 1, '•');
      case ListType.ordered:
        return lineText;
    }
  }
}
