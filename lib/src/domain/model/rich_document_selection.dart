class RichTextPosition {
  const RichTextPosition({required this.blockId, required this.offset});

  final String blockId;
  final int offset;

  RichTextPosition copyWith({String? blockId, int? offset}) {
    return RichTextPosition(
      blockId: blockId ?? this.blockId,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RichTextPosition &&
            blockId == other.blockId &&
            offset == other.offset);
  }

  @override
  int get hashCode => Object.hash(blockId, offset);
}

class RichSelection {
  const RichSelection({required this.base, required this.extent});

  factory RichSelection.collapsed(RichTextPosition position) {
    return RichSelection(base: position, extent: position);
  }

  final RichTextPosition base;
  final RichTextPosition extent;

  bool get isCollapsed =>
      base.blockId == extent.blockId && base.offset == extent.offset;

  RichSelection collapseToExtent() {
    return RichSelection.collapsed(extent);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RichSelection &&
            base == other.base &&
            extent == other.extent);
  }

  @override
  int get hashCode => Object.hash(base, extent);
}
