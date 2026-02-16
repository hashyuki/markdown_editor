import '../model/rich_document.dart';

abstract interface class BlockIdGenerator {
  String nextBlockId(RichDocument document);
}

class BlockIdAllocator implements BlockIdGenerator {
  const BlockIdAllocator();

  @override
  String nextBlockId(RichDocument document) {
    var max = -1;
    final pattern = RegExp(r'^b(\d+)$');
    for (final block in document.blocks) {
      final match = pattern.firstMatch(block.id);
      if (match == null) {
        continue;
      }
      final value = int.parse(match.group(1)!);
      if (value > max) {
        max = value;
      }
    }
    return 'b${max + 1}';
  }
}
