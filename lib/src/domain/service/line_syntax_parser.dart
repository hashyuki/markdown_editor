import '../model/editor_line.dart';
import '../model/line_syntax.dart';

abstract interface class LineSyntaxParser {
  const LineSyntaxParser();

  LineSyntax parse(String line);
}

class MarkdownLineSyntaxParser implements LineSyntaxParser {
  const MarkdownLineSyntaxParser();

  static final RegExp _unorderedListPattern = RegExp(
    r'^((?:  )*)([*+-])\s(.*)$',
  );
  static final RegExp _orderedListPattern = RegExp(r'^((?:  )*)(\d+)\. (.*)$');

  @override
  LineSyntax parse(String line) {
    final unorderedMatch = _unorderedListPattern.firstMatch(line);
    if (unorderedMatch != null) {
      final indent = unorderedMatch.group(1)!.length ~/ 2;
      final marker = unorderedMatch.group(2)!;
      return LineSyntax(
        headingLevel: EditorLine(line).headingLevel,
        list: ListSyntax.unordered(indent: indent, marker: marker),
      );
    }

    final orderedMatch = _orderedListPattern.firstMatch(line);
    if (orderedMatch != null) {
      final indent = orderedMatch.group(1)!.length ~/ 2;
      final number = int.parse(orderedMatch.group(2)!);
      return LineSyntax(
        headingLevel: EditorLine(line).headingLevel,
        list: ListSyntax.ordered(indent: indent, number: number),
      );
    }

    return LineSyntax(headingLevel: EditorLine(line).headingLevel);
  }
}

@Deprecated('Use MarkdownLineSyntaxParser instead.')
class HeadingLineSyntaxParser extends MarkdownLineSyntaxParser {
  const HeadingLineSyntaxParser();
}
