class EditorLine {
  const EditorLine(this.value);

  static final RegExp _headingPattern = RegExp(r'^\s{0,3}(#{1,6})\s');

  final String value;

  int? get headingLevel {
    final match = _headingPattern.firstMatch(value);
    return match?.group(1)?.length;
  }
}
