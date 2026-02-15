class LineTextRange {
  const LineTextRange({required this.start, required this.end});

  final int start;
  final int end;
}

LineTextRange lineTextRangeForOffset(String text, int offset) {
  final lineStart = offset == 0 ? 0 : (text.lastIndexOf('\n', offset - 1) + 1);
  final lineEnd = text.indexOf('\n', offset);
  return LineTextRange(
    start: lineStart,
    end: lineEnd == -1 ? text.length : lineEnd,
  );
}
