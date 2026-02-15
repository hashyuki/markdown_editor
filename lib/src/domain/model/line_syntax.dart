enum ListType { unordered, ordered }

class ListSyntax {
  const ListSyntax.unordered({required this.indent, required this.marker})
    : type = ListType.unordered,
      number = null;

  const ListSyntax.ordered({required this.indent, required this.number})
    : type = ListType.ordered,
      marker = null;

  final ListType type;
  final int indent;
  final String? marker;
  final int? number;
}

class LineSyntax {
  const LineSyntax({this.headingLevel, this.list});

  final int? headingLevel;
  final ListSyntax? list;
}
