import '../model/line_syntax.dart';
import '../model/rich_document.dart';
import 'line_syntax_parser.dart';

class MarkdownToRichDocumentConverter {
  MarkdownToRichDocumentConverter({LineSyntaxParser? parser})
    : _parser = parser ?? const MarkdownLineSyntaxParser();

  final LineSyntaxParser _parser;

  static final RegExp _orderedListPattern = RegExp(r'^(\s*)(\d+)\.\s+');
  static final RegExp _unorderedListPattern = RegExp(r'^(\s*)[-*+]\s+');
  static final RegExp _headingPattern = RegExp(r'^\s{0,3}(#{1,6})\s+');
  static final RegExp _blockquotePattern = RegExp(r'^\s{0,3}>\s?');

  RichDocument convert(String markdown) {
    final lines = markdown.split('\n');
    final blocks = <BlockNode>[];
    var blockIndex = 0;

    for (final rawLine in lines) {
      final syntax = _parser.parse(rawLine);
      final block = _lineToBlock(
        id: 'b$blockIndex',
        line: rawLine,
        syntax: syntax,
      );
      blocks.add(block);
      blockIndex += 1;
    }

    if (blocks.isEmpty) {
      return RichDocument.empty();
    }

    return RichDocument(blocks: blocks);
  }

  BlockNode _lineToBlock({
    required String id,
    required String line,
    required LineSyntax syntax,
  }) {
    final headingMatch = _headingPattern.firstMatch(line);
    if (headingMatch != null) {
      final marker = headingMatch.group(1)!;
      final content = line.substring(headingMatch.end);
      return BlockNode(
        id: id,
        type: BlockType.heading,
        headingLevel: marker.length,
        inlines: _plainInline(content),
      );
    }

    final list = syntax.list;
    if (list != null) {
      if (list.type == ListType.ordered) {
        final match = _orderedListPattern.firstMatch(line);
        final content = match == null ? line : line.substring(match.end);
        return BlockNode(
          id: id,
          type: BlockType.orderedListItem,
          indent: list.indent,
          inlines: _plainInline(content),
        );
      }
      final match = _unorderedListPattern.firstMatch(line);
      final content = match == null ? line : line.substring(match.end);
      return BlockNode(
        id: id,
        type: BlockType.bulletListItem,
        indent: list.indent,
        inlines: _plainInline(content),
      );
    }

    final quoteMatch = _blockquotePattern.firstMatch(line);
    if (quoteMatch != null) {
      final content = line.substring(quoteMatch.end);
      return BlockNode(
        id: id,
        type: BlockType.quote,
        inlines: _plainInline(content),
      );
    }

    return BlockNode(
      id: id,
      type: BlockType.paragraph,
      inlines: _plainInline(line),
    );
  }

  List<InlineText> _plainInline(String text) {
    if (text.isEmpty) {
      return const <InlineText>[];
    }
    return <InlineText>[InlineText(text: text)];
  }
}
