import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  testWidgets('keyboard selection moves with arrow keys', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode.paragraph(id: 'b1', text: 'abc'),
        BlockNode.paragraph(id: 'b2', text: 'xy'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(selections.last.extent.blockId, 'b1');
    expect(selections.last.extent.offset, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(selections.last.extent.blockId, 'b1');
    expect(selections.last.extent.offset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(selections.last.extent.blockId, 'b2');
    expect(selections.last.extent.offset, 0);
  });

  testWidgets('shift+arrow expands selection', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'abc')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(selections.last.base.offset, 0);
    expect(selections.last.extent.offset, 1);
    expect(selections.last.isCollapsed, isFalse);
  });

  testWidgets('tap updates caret position in block', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'abc')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    final richTextFinder = find.byWidgetPredicate((widget) {
      if (widget is! RichText) {
        return false;
      }
      return widget.text.toPlainText() == 'abc';
    });
    final rect = tester.getRect(richTextFinder);
    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pump();
    expect(selections.last.extent.offset, 0);

    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pump();
    expect(selections.last.extent.offset, 3);
    expect(selections.last.extent.blockId, 'b1');
  });

  testWidgets('keyboard editing inserts, splits, and merges blocks', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_plainRichTexts(tester), contains('abx'));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'y',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_plainRichTexts(tester), contains('abx'));
    expect(_plainRichTexts(tester), contains('y'));

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_plainRichTexts(tester), contains('abx'));
    expect(_plainRichTexts(tester).where((text) => text == 'abx').length, 1);
  });

  testWidgets('mouse drag selects text in a block', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'abcdef')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    final richTextFinder = find.byWidgetPredicate((widget) {
      if (widget is! RichText) {
        return false;
      }
      return widget.text.toPlainText() == 'abcdef';
    });
    final rect = tester.getRect(richTextFinder);
    await tester.dragFrom(
      Offset(rect.left + 1, rect.center.dy),
      Offset((rect.width * 0.5), 0),
    );
    await tester.pump();

    expect(selections, isNotEmpty);
    expect(selections.last.base.blockId, 'b1');
    expect(selections.last.extent.blockId, 'b1');
    expect(selections.last.isCollapsed, isFalse);
  });

  testWidgets('shift+click selects across multiple blocks', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode.paragraph(id: 'b1', text: 'first line'),
        BlockNode.paragraph(id: 'b2', text: 'second line'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(_richTextWithPlainText('first line')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(tester.getCenter(_richTextWithPlainText('second line')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(selections, isNotEmpty);
    expect(selections.last.isCollapsed, isFalse);
    expect(
      <String>{selections.last.base.blockId, selections.last.extent.blockId},
      <String>{'b1', 'b2'},
    );
  });

  testWidgets('shows caret when focused with collapsed selection', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'abc')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('rich_document_caret')), findsNothing);

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(find.byKey(const Key('rich_document_caret')), findsOneWidget);
  });

  testWidgets('active heading block shows markdown syntax in live preview', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.heading,
          headingLevel: 1,
          inlines: <InlineText>[InlineText(text: 'Title')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    expect(_richTextWithPlainText('Title'), findsOneWidget);
    expect(_richTextWithPlainText('# Title'), findsNothing);

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(_richTextWithPlainText('# Title'), findsOneWidget);
  });

  testWidgets('cmd+a selects all document content', (tester) async {
    final selections = <RichSelection>[];
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode.paragraph(id: 'b1', text: 'abc'),
        BlockNode.paragraph(id: 'b2', text: 'xy'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(selections, isNotEmpty);
    expect(selections.last.base.blockId, 'b1');
    expect(selections.last.base.offset, 0);
    expect(selections.last.extent.blockId, 'b2');
    expect(selections.last.extent.offset, 2);
  });

  testWidgets('cmd+c copies selected text to clipboard', (tester) async {
    String clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            clipboardText = arguments['text'] as String? ?? '';
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode.paragraph(id: 'b1', text: 'abc'),
        BlockNode.paragraph(id: 'b2', text: 'xy'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(clipboardText, 'abc\nxy');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('cmd+c copies current line when selection is collapsed', (
    tester,
  ) async {
    String clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            clipboardText = arguments['text'] as String? ?? '';
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode.paragraph(id: 'b1', text: 'abc'),
        BlockNode.paragraph(id: 'b2', text: 'xyz'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
              selection: RichSelection.collapsed(
                const RichTextPosition(blockId: 'b2', offset: 1),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(clipboardText, 'xyz');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('cmd+v pastes clipboard text including new lines', (
    tester,
  ) async {
    String clipboardText = 'hello\nworld';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            clipboardText = arguments['text'] as String? ?? '';
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(_richTextWithPlainText('hello'), findsOneWidget);
    expect(_richTextWithPlainText('world'), findsOneWidget);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('cmd+z undo and shift+cmd+z redo document edits', (tester) async {
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
              selection: RichSelection.collapsed(
                const RichTextPosition(blockId: 'b1', offset: 2),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_richTextWithPlainText('abx'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_richTextWithPlainText('ab'), findsOneWidget);
    expect(_richTextWithPlainText('abx'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_richTextWithPlainText('abx'), findsOneWidget);
  });

  testWidgets('cmd+z works in controlled mode', (tester) async {
    var document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
    );
    var selection = RichSelection.collapsed(
      const RichTextPosition(blockId: 'b1', offset: 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SizedBox(
                height: 300,
                child: RichDocumentView(
                  document: document,
                  selection: selection,
                  enableKeyboardSelection: true,
                  enableKeyboardEditing: true,
                  onDocumentChanged: (next) {
                    setState(() {
                      document = next;
                    });
                  },
                  onSelectionChanged: (next) {
                    setState(() {
                      selection = next;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_richTextWithPlainText('abx'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(_richTextWithPlainText('ab'), findsOneWidget);
    expect(_richTextWithPlainText('abx'), findsNothing);
  });

  testWidgets('tap after undo does not crash with stale hit targets', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'ab')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
              selection: RichSelection.collapsed(
                const RichTextPosition(blockId: 'b1', offset: 2),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_richTextWithPlainText('abx'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(_richTextWithPlainText('ab'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ime commit inserts japanese text once', (tester) async {
    final document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: '')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'あ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(_richTextWithPlainText('あ'), findsOneWidget);
    expect(find.byKey(const Key('rich_document_caret')), findsOneWidget);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'あ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(_richTextWithPlainText('あ'), findsOneWidget);
  });

  testWidgets('ime replace in controlled mode keeps first composed char', (
    tester,
  ) async {
    var document = RichDocument(
      blocks: <BlockNode>[BlockNode.paragraph(id: 'b1', text: 'あいうえお')],
    );
    var selection = RichSelection.collapsed(
      const RichTextPosition(blockId: 'b1', offset: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SizedBox(
                height: 300,
                child: RichDocumentView(
                  document: document,
                  selection: selection,
                  enableKeyboardSelection: true,
                  enableKeyboardEditing: true,
                  onDocumentChanged: (next) {
                    setState(() {
                      document = next;
                    });
                  },
                  onSelectionChanged: (next) {
                    setState(() {
                      selection = next;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'か',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'かきくけこ',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();

    expect(_richTextWithPlainText('かきくけこ'), findsOneWidget);
    expect(_richTextWithPlainText('きくけこ'), findsNothing);
  });

  testWidgets('does not duplicate heading marker while editing', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.heading,
          headingLevel: 2,
          inlines: <InlineText>[InlineText(text: '## hello')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(_richTextWithPlainText('## hello'), findsOneWidget);
    expect(_richTextWithPlainText('## ## hello'), findsNothing);
  });

  testWidgets('does not prepend marker when heading text is only "#"', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.heading,
          headingLevel: 1,
          inlines: <InlineText>[InlineText(text: '#')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(_richTextWithPlainText('#'), findsOneWidget);
    expect(_richTextWithPlainText('# #'), findsNothing);
  });

  testWidgets('bullet list renders dot while keeping markdown text model', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.bulletListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '- aaa')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('•'), findsOneWidget);
    expect(_richTextWithPlainText('aaa'), findsOneWidget);
    expect(_richTextWithPlainText('- aaa'), findsNothing);

    await tester.tap(find.byKey(const Key('rich_document_view_focus')));
    await tester.pump();

    expect(find.text('•'), findsOneWidget);
    expect(_richTextWithPlainText('aaa'), findsOneWidget);
    expect(_richTextWithPlainText('- aaa'), findsNothing);
  });

  testWidgets('nested bullet marker aligns with parent text start', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.bulletListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '- aaa')],
        ),
        BlockNode(
          id: 'b2',
          type: BlockType.bulletListItem,
          indent: 1,
          inlines: <InlineText>[InlineText(text: '  - aaa')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    final bulletElements = find.text('•').evaluate().toList(growable: false);
    expect(bulletElements.length, 2);
    final parentBulletRect = tester.getRect(
      find.byElementPredicate((element) {
        return identical(element, bulletElements[0]);
      }),
    );
    final childBulletRect = tester.getRect(
      find.byElementPredicate((element) {
        return identical(element, bulletElements[1]);
      }),
    );

    final aaaRichTexts = find.byWidgetPredicate((widget) {
      if (widget is! RichText) {
        return false;
      }
      return widget.text.toPlainText() == 'aaa';
    });
    final parentTextRect = tester.getRect(aaaRichTexts.first);

    expect(childBulletRect.left, closeTo(parentTextRect.left, 0.1));
    expect(parentBulletRect.left, lessThan(childBulletRect.left));
  });

  testWidgets('ordered list displays sequential numbers per indent level', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. aaa')],
        ),
        BlockNode(
          id: 'b2',
          type: BlockType.orderedListItem,
          indent: 1,
          inlines: <InlineText>[InlineText(text: '  1. aaa')],
        ),
        BlockNode(
          id: 'b3',
          type: BlockType.orderedListItem,
          indent: 1,
          inlines: <InlineText>[InlineText(text: '  1. aaa')],
        ),
        BlockNode(
          id: 'b4',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. aaa')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    final markerTexts = _orderedMarkerTexts(tester);
    expect(markerTexts, <String>['1.', '1.', '2.', '2.']);
  });

  testWidgets('ordered list increments on same indent level', (tester) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. aaa')],
        ),
        BlockNode(
          id: 'b2',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. bbb')],
        ),
        BlockNode(
          id: 'b3',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. ccc')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    final markerTexts = _orderedMarkerTexts(tester);
    expect(markerTexts, <String>['1.', '2.', '3.']);
  });

  testWidgets('ordered list continues numbering after nested items', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. top')],
        ),
        BlockNode(
          id: 'b2',
          type: BlockType.orderedListItem,
          indent: 1,
          inlines: <InlineText>[InlineText(text: '  1. nested-a')],
        ),
        BlockNode(
          id: 'b3',
          type: BlockType.orderedListItem,
          indent: 1,
          inlines: <InlineText>[InlineText(text: '  1. nested-b')],
        ),
        BlockNode(
          id: 'b4',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. second')],
        ),
        BlockNode(
          id: 'b5',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. third')],
        ),
        BlockNode(
          id: 'b6',
          type: BlockType.orderedListItem,
          indent: 0,
          inlines: <InlineText>[InlineText(text: '1. fourth')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(
              document: document,
              enableKeyboardSelection: true,
              enableKeyboardEditing: true,
            ),
          ),
        ),
      ),
    );

    final markerTexts = _orderedMarkerTexts(tester);
    expect(markerTexts, <String>['1.', '1.', '2.', '2.', '3.', '4.']);
  });

  testWidgets('inline bold mark is reflected in rendered text style', (
    tester,
  ) async {
    final document = RichDocument(
      blocks: <BlockNode>[
        BlockNode(
          id: 'b1',
          type: BlockType.paragraph,
          inlines: <InlineText>[
            InlineText(text: 'bold', marks: <InlineMark>{InlineMark.bold}),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: RichDocumentView(document: document),
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(_richTextWithPlainText('bold'));
    final rootSpan = richText.text as TextSpan;
    final boldSpan = rootSpan.children!.first as TextSpan;
    expect(boldSpan.style?.fontWeight, FontWeight.w700);
  });
}

List<String> _plainRichTexts(WidgetTester tester) {
  return find
      .byType(RichText)
      .evaluate()
      .map((element) => (element.widget as RichText).text.toPlainText())
      .toList(growable: false);
}

Finder _richTextWithPlainText(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! RichText) {
      return false;
    }
    return widget.text.toPlainText() == text;
  });
}

List<String> _orderedMarkerTexts(WidgetTester tester) {
  return find
      .byType(Text)
      .evaluate()
      .map((element) => element.widget as Text)
      .map((text) => text.data ?? '')
      .where((data) => RegExp(r'^\d+\.$').hasMatch(data))
      .toList(growable: false);
}
