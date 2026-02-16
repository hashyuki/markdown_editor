import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/main.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  testWidgets('demo renders textfield-free rich document view', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(RichDocumentView), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
    expect(
      find.textContaining('TextField-free Editor Prototype'),
      findsOneWidget,
    );
  });
}
