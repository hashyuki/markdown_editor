import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/main.dart';

void main() {
  testWidgets('simple editor accepts input', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byKey(const Key('simple_text_editor_input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('simple_text_editor_input')),
      '# Hello markdown',
    );
    await tester.pump();

    expect(find.text('# Hello markdown'), findsOneWidget);
  });
}
