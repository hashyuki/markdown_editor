import '../model/editor_line.dart';
import '../model/line_syntax.dart';

abstract interface class LineSyntaxParser {
  const LineSyntaxParser();

  LineSyntax parse(String line);
}

class HeadingLineSyntaxParser implements LineSyntaxParser {
  const HeadingLineSyntaxParser();

  @override
  LineSyntax parse(String line) {
    return LineSyntax(headingLevel: EditorLine(line).headingLevel);
  }
}
