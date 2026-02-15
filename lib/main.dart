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
  late final EditorViewModel _viewModel;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final repository = InMemoryEditorRepository();
    _viewModel = EditorViewModel(
      loadUseCase: LoadEditorDocumentUseCase(repository),
      updateUseCase: UpdateEditorDocumentUseCase(repository),
    )..initialize();
    _controller = TextEditingController(text: _viewModel.text)
      ..addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    _viewModel.onTextChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onEditorChanged)
      ..dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Text Editor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SimpleTextEditor(
          controller: _controller,
          hintText: 'Start writing markdown...',
        ),
      ),
    );
  }
}
