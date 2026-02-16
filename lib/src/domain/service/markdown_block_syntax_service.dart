import '../model/rich_document.dart';
import '../service/rich_document_transaction.dart';

abstract interface class BlockSyntaxService {
  bool isMarkerOnlyListBlock(BlockNode block);

  bool isListLine(String line);

  bool isBulletMarkerOnlyText(String text);

  bool isOrderedMarkerOnlyText(String text);

  RichDocument synchronizeBlockSyntaxFromText(
    RichDocument document,
    String blockId,
  );

  ({String text, int indent}) replaceBulletIndentText(String text, int indent);

  ({String text, int indent}) replaceOrderedIndentText(String text, int indent);

  String? bulletMarker(String text);

  int? orderedMarker(String text);

  int bulletPrefixLength(int indent);

  int orderedPrefixLength(int indent, int marker);

  String indentSpaces(int indent);
}

class MarkdownBlockSyntaxService implements BlockSyntaxService {
  const MarkdownBlockSyntaxService();

  static final RegExp headingPattern = RegExp(r'^(#{1,6}) ');
  static final RegExp bulletPattern = RegExp(r'^((?:  )*)([-*+]) ');
  static final RegExp bulletOnlyPattern = RegExp(r'^((?:  )*)([-*+])\s*$');
  static final RegExp orderedPattern = RegExp(r'^((?:  )*)(\d+)\.\s');
  static final RegExp orderedOnlyPattern = RegExp(r'^((?:  )*)(\d+)\.\s*$');

  @override
  bool isMarkerOnlyListBlock(BlockNode block) {
    if (block.type == BlockType.bulletListItem) {
      return bulletOnlyPattern.hasMatch(block.plainText);
    }
    if (block.type == BlockType.orderedListItem) {
      return orderedOnlyPattern.hasMatch(block.plainText);
    }
    return false;
  }

  @override
  bool isListLine(String line) {
    return bulletPattern.hasMatch(line) || orderedPattern.hasMatch(line);
  }

  @override
  bool isBulletMarkerOnlyText(String text) {
    return bulletOnlyPattern.hasMatch(text);
  }

  @override
  bool isOrderedMarkerOnlyText(String text) {
    return orderedOnlyPattern.hasMatch(text);
  }

  @override
  RichDocument synchronizeBlockSyntaxFromText(
    RichDocument document,
    String blockId,
  ) {
    if (document.indexOfBlock(blockId) == -1) {
      return document;
    }
    final block = document.blockById(blockId);
    if (block.type != BlockType.paragraph &&
        block.type != BlockType.heading &&
        block.type != BlockType.bulletListItem &&
        block.type != BlockType.orderedListItem) {
      return document;
    }

    final headingMatch = headingPattern.firstMatch(block.plainText);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      if (block.type == BlockType.heading && block.headingLevel == level) {
        return document;
      }
      return SetBlockTypeCommand(
        blockId: block.id,
        type: BlockType.heading,
        headingLevel: level,
      ).apply(document);
    }

    final bulletMatch = bulletPattern.firstMatch(block.plainText);
    if (bulletMatch != null) {
      final leadingSpaces = bulletMatch.group(1)!.length;
      final indent = leadingSpaces ~/ 2;
      if (block.type == BlockType.bulletListItem && block.indent == indent) {
        return document;
      }
      return SetBlockTypeCommand(
        blockId: block.id,
        type: BlockType.bulletListItem,
        indent: indent,
      ).apply(document);
    }

    final orderedMatch = orderedPattern.firstMatch(block.plainText);
    if (orderedMatch != null) {
      final leadingSpaces = orderedMatch.group(1)!.length;
      final indent = leadingSpaces ~/ 2;
      if (block.type == BlockType.orderedListItem && block.indent == indent) {
        return document;
      }
      return SetBlockTypeCommand(
        blockId: block.id,
        type: BlockType.orderedListItem,
        indent: indent,
      ).apply(document);
    }

    if (block.type == BlockType.heading ||
        block.type == BlockType.bulletListItem ||
        block.type == BlockType.orderedListItem) {
      return SetBlockTypeCommand(
        blockId: block.id,
        type: BlockType.paragraph,
      ).apply(document);
    }
    return document;
  }

  @override
  ({String text, int indent}) replaceBulletIndentText(String text, int indent) {
    final match = bulletPattern.firstMatch(text);
    if (match == null) {
      return (text: text, indent: indent);
    }
    final marker = match.group(2)!;
    final content = text.substring(match.end);
    final replaced = '${indentSpaces(indent)}$marker $content';
    return (text: replaced, indent: indent);
  }

  @override
  ({String text, int indent}) replaceOrderedIndentText(
    String text,
    int indent,
  ) {
    final match = orderedPattern.firstMatch(text);
    if (match == null) {
      return (text: text, indent: indent);
    }
    final marker = match.group(2)!;
    final content = text.substring(match.end);
    final replaced = '${indentSpaces(indent)}$marker. $content';
    return (text: replaced, indent: indent);
  }

  @override
  String? bulletMarker(String text) {
    final match = bulletPattern.firstMatch(text);
    return match?.group(2);
  }

  @override
  int? orderedMarker(String text) {
    final match = orderedPattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(2)!);
  }

  @override
  int bulletPrefixLength(int indent) {
    return (indent * 2) + 2;
  }

  @override
  int orderedPrefixLength(int indent, int marker) {
    return (indent * 2) + marker.toString().length + 2;
  }

  @override
  String indentSpaces(int indent) {
    return List<String>.filled(indent, '  ').join();
  }
}
