enum BlockType {
  paragraph,
  heading,
  bulletListItem,
  orderedListItem,
  codeBlock,
  quote,
  table,
}

enum InlineMark { bold, italic, code }

class InlineText {
  const InlineText({
    required this.text,
    this.marks = const <InlineMark>{},
    this.link,
  });

  final String text;
  final Set<InlineMark> marks;
  final String? link;

  bool get isEmpty => text.isEmpty;

  InlineText copyWith({
    String? text,
    Set<InlineMark>? marks,
    String? link,
    bool clearLink = false,
  }) {
    return InlineText(
      text: text ?? this.text,
      marks: marks ?? this.marks,
      link: clearLink ? null : (link ?? this.link),
    );
  }
}

class BlockNode {
  const BlockNode({
    required this.id,
    required this.type,
    required this.inlines,
    this.headingLevel,
    this.indent = 0,
    this.codeLanguage,
  }) : assert(
         headingLevel == null || (headingLevel >= 1 && headingLevel <= 6),
         'headingLevel must be between 1 and 6.',
       );

  factory BlockNode.paragraph({
    required String id,
    String text = '',
    Set<InlineMark> marks = const <InlineMark>{},
  }) {
    return BlockNode(
      id: id,
      type: BlockType.paragraph,
      inlines: <InlineText>[InlineText(text: text, marks: marks)],
    );
  }

  final String id;
  final BlockType type;
  final List<InlineText> inlines;
  final int? headingLevel;
  final int indent;
  final String? codeLanguage;

  String get plainText => inlines.map((inline) => inline.text).join();

  int get textLength => plainText.length;

  BlockNode copyWith({
    String? id,
    BlockType? type,
    List<InlineText>? inlines,
    int? headingLevel,
    bool clearHeadingLevel = false,
    int? indent,
    String? codeLanguage,
    bool clearCodeLanguage = false,
  }) {
    return BlockNode(
      id: id ?? this.id,
      type: type ?? this.type,
      inlines: inlines ?? this.inlines,
      headingLevel: clearHeadingLevel
          ? null
          : (headingLevel ?? this.headingLevel),
      indent: indent ?? this.indent,
      codeLanguage: clearCodeLanguage
          ? null
          : (codeLanguage ?? this.codeLanguage),
    );
  }
}

class RichDocument {
  RichDocument({required this.blocks}) : assert(blocks.isNotEmpty);

  factory RichDocument.empty() {
    return RichDocument(
      blocks: <BlockNode>[
        BlockNode(id: 'b0', type: BlockType.paragraph, inlines: <InlineText>[]),
      ],
    );
  }

  final List<BlockNode> blocks;

  int indexOfBlock(String blockId) {
    return blocks.indexWhere((block) => block.id == blockId);
  }

  BlockNode blockById(String blockId) {
    final index = indexOfBlock(blockId);
    if (index == -1) {
      throw StateError('Block not found: $blockId');
    }
    return blocks[index];
  }

  RichDocument replaceBlock(BlockNode nextBlock) {
    final index = indexOfBlock(nextBlock.id);
    if (index == -1) {
      throw StateError('Block not found: ${nextBlock.id}');
    }
    final nextBlocks = List<BlockNode>.of(blocks)..[index] = nextBlock;
    return RichDocument(blocks: nextBlocks);
  }

  RichDocument insertBlockAfter({
    required String targetBlockId,
    required BlockNode newBlock,
  }) {
    final index = indexOfBlock(targetBlockId);
    if (index == -1) {
      throw StateError('Block not found: $targetBlockId');
    }
    final nextBlocks = List<BlockNode>.of(blocks)..insert(index + 1, newBlock);
    return RichDocument(blocks: nextBlocks);
  }

  RichDocument removeBlockById(String blockId) {
    if (blocks.length == 1) {
      throw StateError('Cannot remove the last block in a document.');
    }
    final index = indexOfBlock(blockId);
    if (index == -1) {
      throw StateError('Block not found: $blockId');
    }
    final nextBlocks = List<BlockNode>.of(blocks)..removeAt(index);
    return RichDocument(blocks: nextBlocks);
  }
}
