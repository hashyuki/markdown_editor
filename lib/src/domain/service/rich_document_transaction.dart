import '../model/rich_document.dart';

class RichDocumentTransaction {
  const RichDocumentTransaction({required this.commands});

  final List<RichDocumentEditCommand> commands;

  RichDocument apply(RichDocument document) {
    var current = document;
    for (final command in commands) {
      current = command.apply(current);
    }
    return current;
  }
}

abstract interface class RichDocumentEditCommand {
  RichDocument apply(RichDocument document);
}

class InsertTextCommand implements RichDocumentEditCommand {
  const InsertTextCommand({
    required this.blockId,
    required this.offset,
    required this.text,
  });

  final String blockId;
  final int offset;
  final String text;

  @override
  RichDocument apply(RichDocument document) {
    final block = document.blockById(blockId);
    final nextInlines = _insertText(
      block.inlines,
      offset: offset,
      text: text,
      fallbackMarks: const <InlineMark>{},
    );
    return document.replaceBlock(block.copyWith(inlines: nextInlines));
  }
}

class DeleteTextRangeCommand implements RichDocumentEditCommand {
  const DeleteTextRangeCommand({
    required this.blockId,
    required this.start,
    required this.end,
  });

  final String blockId;
  final int start;
  final int end;

  @override
  RichDocument apply(RichDocument document) {
    final block = document.blockById(blockId);
    final nextInlines = _deleteTextRange(block.inlines, start: start, end: end);
    return document.replaceBlock(block.copyWith(inlines: nextInlines));
  }
}

class SplitBlockCommand implements RichDocumentEditCommand {
  const SplitBlockCommand({
    required this.blockId,
    required this.offset,
    required this.newBlockId,
  });

  final String blockId;
  final int offset;
  final String newBlockId;

  @override
  RichDocument apply(RichDocument document) {
    final block = document.blockById(blockId);
    final split = _splitInlines(block.inlines, offset: offset);
    final currentBlock = block.copyWith(inlines: split.left);
    final nextBlock = block.copyWith(id: newBlockId, inlines: split.right);
    return document
        .replaceBlock(currentBlock)
        .insertBlockAfter(targetBlockId: blockId, newBlock: nextBlock);
  }
}

class MergeWithPreviousBlockCommand implements RichDocumentEditCommand {
  const MergeWithPreviousBlockCommand({required this.blockId});

  final String blockId;

  @override
  RichDocument apply(RichDocument document) {
    final currentIndex = document.indexOfBlock(blockId);
    if (currentIndex <= 0) {
      return document;
    }

    final previousBlock = document.blocks[currentIndex - 1];
    final currentBlock = document.blocks[currentIndex];
    final merged = _normalizeSegments(<_Segment>[
      ..._toSegments(previousBlock.inlines),
      ..._toSegments(currentBlock.inlines),
    ]);
    final mergedBlock = previousBlock.copyWith(inlines: _fromSegments(merged));

    return document.replaceBlock(mergedBlock).removeBlockById(currentBlock.id);
  }
}

class ToggleInlineMarkCommand implements RichDocumentEditCommand {
  const ToggleInlineMarkCommand({
    required this.blockId,
    required this.start,
    required this.end,
    required this.mark,
  });

  final String blockId;
  final int start;
  final int end;
  final InlineMark mark;

  @override
  RichDocument apply(RichDocument document) {
    final block = document.blockById(blockId);
    final nextInlines = _toggleMark(
      block.inlines,
      start: start,
      end: end,
      mark: mark,
    );
    return document.replaceBlock(block.copyWith(inlines: nextInlines));
  }
}

class SetBlockTypeCommand implements RichDocumentEditCommand {
  const SetBlockTypeCommand({
    required this.blockId,
    required this.type,
    this.headingLevel,
    this.indent,
    this.codeLanguage,
  }) : assert(
         type != BlockType.heading || headingLevel != null,
         'headingLevel is required when setting heading type.',
       ),
       assert(indent == null || indent >= 0, 'indent must be non-negative.');

  final String blockId;
  final BlockType type;
  final int? headingLevel;
  final int? indent;
  final String? codeLanguage;

  @override
  RichDocument apply(RichDocument document) {
    final block = document.blockById(blockId);
    final nextIndent =
        type == BlockType.bulletListItem || type == BlockType.orderedListItem
        ? (indent ?? block.indent)
        : 0;
    return document.replaceBlock(
      block.copyWith(
        type: type,
        headingLevel: type == BlockType.heading ? headingLevel : null,
        clearHeadingLevel: type != BlockType.heading,
        indent: nextIndent,
        codeLanguage: type == BlockType.codeBlock ? codeLanguage : null,
        clearCodeLanguage: type != BlockType.codeBlock,
      ),
    );
  }
}

class _SplitResult {
  const _SplitResult({required this.left, required this.right});

  final List<InlineText> left;
  final List<InlineText> right;
}

class _Segment {
  const _Segment({required this.text, required this.marks, required this.link});

  final String text;
  final Set<InlineMark> marks;
  final String? link;

  bool sameStyle(_Segment other) {
    if (link != other.link) {
      return false;
    }
    if (marks.length != other.marks.length) {
      return false;
    }
    for (final mark in marks) {
      if (!other.marks.contains(mark)) {
        return false;
      }
    }
    return true;
  }
}

List<InlineText> _insertText(
  List<InlineText> inlines, {
  required int offset,
  required String text,
  required Set<InlineMark> fallbackMarks,
}) {
  if (text.isEmpty) {
    return inlines;
  }

  final segments = _toSegments(inlines);
  final plainLength = segments.fold<int>(
    0,
    (total, segment) => total + segment.text.length,
  );
  final boundedOffset = offset.clamp(0, plainLength);

  var cursor = 0;
  final next = <_Segment>[];
  var inserted = false;

  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;

    if (!inserted &&
        boundedOffset >= segmentStart &&
        boundedOffset <= segmentEnd) {
      final localOffset = boundedOffset - segmentStart;
      final left = segment.text.substring(0, localOffset);
      final right = segment.text.substring(localOffset);

      if (left.isNotEmpty) {
        next.add(
          _Segment(text: left, marks: segment.marks, link: segment.link),
        );
      }

      final inheritMarks = localOffset == 0 && i > 0
          ? next.last.marks
          : segment.marks;
      final marks = inheritMarks.isEmpty ? fallbackMarks : inheritMarks;
      next.add(_Segment(text: text, marks: marks, link: null));

      if (right.isNotEmpty) {
        next.add(
          _Segment(text: right, marks: segment.marks, link: segment.link),
        );
      }
      inserted = true;
    } else {
      next.add(segment);
    }

    cursor = segmentEnd;
  }

  if (!inserted) {
    next.add(_Segment(text: text, marks: fallbackMarks, link: null));
  }

  return _fromSegments(_normalizeSegments(next));
}

List<InlineText> _deleteTextRange(
  List<InlineText> inlines, {
  required int start,
  required int end,
}) {
  if (start >= end) {
    return inlines;
  }

  final segments = _toSegments(inlines);
  final plainLength = segments.fold<int>(
    0,
    (total, segment) => total + segment.text.length,
  );
  final rangeStart = start.clamp(0, plainLength);
  final rangeEnd = end.clamp(0, plainLength);

  if (rangeStart >= rangeEnd) {
    return inlines;
  }

  final next = <_Segment>[];
  var cursor = 0;

  for (final segment in segments) {
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;

    if (segmentEnd <= rangeStart || segmentStart >= rangeEnd) {
      next.add(segment);
    } else {
      if (rangeStart > segmentStart) {
        next.add(
          _Segment(
            text: segment.text.substring(0, rangeStart - segmentStart),
            marks: segment.marks,
            link: segment.link,
          ),
        );
      }
      if (rangeEnd < segmentEnd) {
        next.add(
          _Segment(
            text: segment.text.substring(rangeEnd - segmentStart),
            marks: segment.marks,
            link: segment.link,
          ),
        );
      }
    }

    cursor = segmentEnd;
  }

  return _fromSegments(_normalizeSegments(next));
}

_SplitResult _splitInlines(List<InlineText> inlines, {required int offset}) {
  final segments = _toSegments(inlines);
  final plainLength = segments.fold<int>(
    0,
    (total, segment) => total + segment.text.length,
  );
  final boundedOffset = offset.clamp(0, plainLength);

  final left = <_Segment>[];
  final right = <_Segment>[];
  var cursor = 0;

  for (final segment in segments) {
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;

    if (boundedOffset <= segmentStart) {
      right.add(segment);
    } else if (boundedOffset >= segmentEnd) {
      left.add(segment);
    } else {
      final localOffset = boundedOffset - segmentStart;
      final leftText = segment.text.substring(0, localOffset);
      final rightText = segment.text.substring(localOffset);
      if (leftText.isNotEmpty) {
        left.add(
          _Segment(text: leftText, marks: segment.marks, link: segment.link),
        );
      }
      if (rightText.isNotEmpty) {
        right.add(
          _Segment(text: rightText, marks: segment.marks, link: segment.link),
        );
      }
    }

    cursor = segmentEnd;
  }

  return _SplitResult(
    left: _fromSegments(_normalizeSegments(left)),
    right: _fromSegments(_normalizeSegments(right)),
  );
}

List<InlineText> _toggleMark(
  List<InlineText> inlines, {
  required int start,
  required int end,
  required InlineMark mark,
}) {
  if (start >= end) {
    return inlines;
  }

  final segments = _toSegments(inlines);
  final plainLength = segments.fold<int>(
    0,
    (total, segment) => total + segment.text.length,
  );
  final rangeStart = start.clamp(0, plainLength);
  final rangeEnd = end.clamp(0, plainLength);

  if (rangeStart >= rangeEnd) {
    return inlines;
  }

  final splitAtStart = _splitSegments(segments, offset: rangeStart);
  final splitAtEnd = _splitSegments(splitAtStart, offset: rangeEnd);

  var cursor = 0;
  final targetSegments = <_Segment>[];
  for (final segment in splitAtEnd) {
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;
    if (segmentEnd > rangeStart && segmentStart < rangeEnd) {
      targetSegments.add(segment);
    }
    cursor = segmentEnd;
  }

  final shouldAdd = targetSegments.any(
    (segment) => !segment.marks.contains(mark),
  );

  cursor = 0;
  final next = <_Segment>[];
  for (final segment in splitAtEnd) {
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;
    final inRange = segmentEnd > rangeStart && segmentStart < rangeEnd;

    if (!inRange) {
      next.add(segment);
    } else {
      final marks = Set<InlineMark>.of(segment.marks);
      if (shouldAdd) {
        marks.add(mark);
      } else {
        marks.remove(mark);
      }
      next.add(_Segment(text: segment.text, marks: marks, link: segment.link));
    }

    cursor = segmentEnd;
  }

  return _fromSegments(_normalizeSegments(next));
}

List<_Segment> _splitSegments(List<_Segment> segments, {required int offset}) {
  if (segments.isEmpty) {
    return segments;
  }

  final plainLength = segments.fold<int>(
    0,
    (total, segment) => total + segment.text.length,
  );
  final boundedOffset = offset.clamp(0, plainLength);
  if (boundedOffset <= 0 || boundedOffset >= plainLength) {
    return segments;
  }

  final next = <_Segment>[];
  var cursor = 0;

  for (final segment in segments) {
    final segmentStart = cursor;
    final segmentEnd = cursor + segment.text.length;
    if (boundedOffset <= segmentStart || boundedOffset >= segmentEnd) {
      next.add(segment);
    } else {
      final localOffset = boundedOffset - segmentStart;
      final left = segment.text.substring(0, localOffset);
      final right = segment.text.substring(localOffset);
      if (left.isNotEmpty) {
        next.add(
          _Segment(text: left, marks: segment.marks, link: segment.link),
        );
      }
      if (right.isNotEmpty) {
        next.add(
          _Segment(text: right, marks: segment.marks, link: segment.link),
        );
      }
    }
    cursor = segmentEnd;
  }

  return next;
}

List<_Segment> _toSegments(List<InlineText> inlines) {
  if (inlines.isEmpty) {
    return const <_Segment>[];
  }
  return inlines
      .where((inline) => inline.text.isNotEmpty)
      .map(
        (inline) =>
            _Segment(text: inline.text, marks: inline.marks, link: inline.link),
      )
      .toList(growable: false);
}

List<_Segment> _normalizeSegments(List<_Segment> segments) {
  final normalized = <_Segment>[];
  for (final segment in segments) {
    if (segment.text.isEmpty) {
      continue;
    }
    if (normalized.isNotEmpty && normalized.last.sameStyle(segment)) {
      final last = normalized.removeLast();
      normalized.add(
        _Segment(
          text: '${last.text}${segment.text}',
          marks: last.marks,
          link: last.link,
        ),
      );
      continue;
    }
    normalized.add(segment);
  }
  return normalized;
}

List<InlineText> _fromSegments(List<_Segment> segments) {
  return segments
      .map(
        (segment) => InlineText(
          text: segment.text,
          marks: segment.marks,
          link: segment.link,
        ),
      )
      .toList(growable: false);
}
