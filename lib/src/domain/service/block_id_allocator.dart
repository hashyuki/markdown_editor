import '../model/rich_document.dart';

class BlockIdAllocator {
  const BlockIdAllocator();

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
