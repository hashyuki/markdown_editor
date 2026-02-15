import 'package:flutter/material.dart';

/// A minimal plain-text editor that will be the foundation for markdown editing.
class SimpleTextEditor extends StatefulWidget {
  const SimpleTextEditor({
    super.key,
    this.controller,
    this.focusNode,
    this.initialText = '',
    this.onChanged,
    this.hintText = 'Write something...',
    this.autofocus = false,
    this.padding = const EdgeInsets.all(12),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String initialText;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  @override
  State<SimpleTextEditor> createState() => _SimpleTextEditorState();
}

class _SimpleTextEditorState extends State<SimpleTextEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialText);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: widget.padding,
        child: TextField(
          key: const Key('simple_text_editor_input'),
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: null,
          maxLines: null,
          expands: true,
          decoration: InputDecoration.collapsed(hintText: widget.hintText),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
