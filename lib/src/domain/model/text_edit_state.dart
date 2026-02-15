class TextEditState {
  const TextEditState({
    required this.text,
    required this.selectionStart,
    required this.selectionEnd,
  });

  final String text;
  final int selectionStart;
  final int selectionEnd;

  bool get isSelectionValid =>
      selectionStart >= 0 &&
      selectionEnd >= 0 &&
      selectionStart <= text.length &&
      selectionEnd <= text.length;

  bool get isCollapsed => selectionStart == selectionEnd;

  TextEditState copyWith({
    String? text,
    int? selectionStart,
    int? selectionEnd,
  }) {
    return TextEditState(
      text: text ?? this.text,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TextEditState &&
        text == other.text &&
        selectionStart == other.selectionStart &&
        selectionEnd == other.selectionEnd;
  }

  @override
  int get hashCode => Object.hash(text, selectionStart, selectionEnd);
}
