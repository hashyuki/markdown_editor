import 'package:flutter/material.dart';
import 'package:markdown_editor/markdown_editor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  late RichDocument _document;
  RichSelection? _selection;

  @override
  void initState() {
    super.initState();
    const markdown =
        '# Heading 1\n'
        '\n'
        '## Heading 2\n'
        '\n'
        '### Heading 3\n'
        '\n'
        '#### Heading 4\n'
        '\n'
        '##### Heading 5\n'
        '\n'
        '###### Heading 6\n'
        '\n'
        'text text\n'
        '- aaa\n'
        '- bbb\n'
        '  - ccc\n'
        '  - ddd\n'
        '- eee\n'
        '1. aaa\n'
        '1. bbb\n'
        '  1. ccc\n'
        '  1. ddd\n'
        '1. eee';
    _document = MarkdownToRichDocumentConverter().convert(markdown);
    _selection = RichSelection.collapsed(
      RichTextPosition(blockId: _document.blocks.first.id, offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TextField-free Editor Prototype')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichDocumentView(
                document: _document,
                enableKeyboardSelection: true,
                enableKeyboardEditing: true,
                selection: _selection,
                onDocumentChanged: (document) {
                  setState(() {
                    _document = document;
                  });
                },
                onSelectionChanged: (selection) {
                  setState(() {
                    _selection = selection;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
