import 'package:flutter/material.dart';

import 'domain/model/editor_content.dart';
import 'domain/model/editor_line.dart';

class SimpleTextEditorConfig {
  const SimpleTextEditorConfig({
    this.paragraphStyle = _defaultParagraphStyle,
    this.headingStyles = _defaultHeadingStyles,
  });

  static const TextStyle _defaultParagraphStyle = TextStyle(height: 1);

  static const Map<int, TextStyle> _defaultHeadingStyles = <int, TextStyle>{
    1: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.5),
    2: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.4),
    3: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
    4: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2),
    5: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.1),
    6: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1),
  };

  final TextStyle? paragraphStyle;
  final Map<int, TextStyle> headingStyles;
}

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
    this.config = const SimpleTextEditorConfig(),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String initialText;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final SimpleTextEditorConfig config;

  @override
  State<SimpleTextEditor> createState() => _SimpleTextEditorState();
}

class _SimpleTextEditorState extends State<SimpleTextEditor> {
  late final _MarkdownTextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  late final bool _ownsFocusNode;
  TextEditingController? _externalController;
  int? _currentHeadingLevel;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _externalController = widget.controller;
    _controller = _MarkdownTextEditingController(
      text: widget.controller?.text ?? widget.initialText,
      config: widget.config,
    );
    _externalController?.addListener(_syncFromExternalController);
    _controller.addListener(_onInternalControllerChanged);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _updateCursorHeadingLevel();
  }

  @override
  void didUpdateWidget(covariant SimpleTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromExternalController);
      _externalController = widget.controller;
      _externalController?.addListener(_syncFromExternalController);
      _syncFromExternalController();
    }
    if (oldWidget.config != widget.config) {
      _controller.updateConfig(widget.config);
      _updateCursorHeadingLevel();
    }
  }

  void _syncFromExternalController() {
    final externalController = _externalController;
    if (externalController == null) {
      return;
    }
    if (_controller.value == externalController.value) {
      return;
    }
    _controller.value = externalController.value;
  }

  void _syncToExternalController() {
    final externalController = _externalController;
    if (externalController == null) {
      return;
    }
    if (externalController.value == _controller.value) {
      return;
    }
    externalController.value = _controller.value;
  }

  void _onInternalControllerChanged() {
    _syncToExternalController();
    _updateCursorHeadingLevel();
  }

  void _updateCursorHeadingLevel() {
    final headingLevel = _headingLevelForSelection(_controller.value);
    if (_currentHeadingLevel == headingLevel) {
      return;
    }
    if (!mounted) {
      _currentHeadingLevel = headingLevel;
      return;
    }
    setState(() {
      _currentHeadingLevel = headingLevel;
    });
  }

  int? _headingLevelForSelection(TextEditingValue value) {
    final selection = value.selection;
    final text = value.text;
    if (text.isEmpty || !selection.isValid) {
      return null;
    }
    final offset = selection.baseOffset.clamp(0, text.length);
    final lineStart = offset == 0
        ? 0
        : (text.lastIndexOf('\n', offset - 1) + 1);
    final lineEnd = text.indexOf('\n', offset);
    final safeLineEnd = lineEnd == -1 ? text.length : lineEnd;
    final lineText = text.substring(lineStart, safeLineEnd);
    return EditorLine(lineText).headingLevel;
  }

  double _cursorHeightForCurrentLine(BuildContext context) {
    final paragraphStyle = DefaultTextStyle.of(
      context,
    ).style.merge(widget.config.paragraphStyle);
    final lineStyle = _currentHeadingLevel == null
        ? paragraphStyle
        : paragraphStyle.merge(
            widget.config.headingStyles[_currentHeadingLevel],
          );
    return lineStyle.fontSize ?? paragraphStyle.fontSize ?? 14;
  }

  @override
  void dispose() {
    _externalController?.removeListener(_syncFromExternalController);
    _controller.removeListener(_onInternalControllerChanged);
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
          strutStyle: StrutStyle.disabled,
          cursorHeight: _cursorHeightForCurrentLine(context),
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

class _MarkdownTextEditingController extends TextEditingController {
  _MarkdownTextEditingController({
    super.text,
    required SimpleTextEditorConfig config,
  }) : _config = config;

  SimpleTextEditorConfig _config;

  void updateConfig(SimpleTextEditorConfig config) {
    _config = config;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = (style ?? DefaultTextStyle.of(context).style).merge(
      _config.paragraphStyle,
    );
    final lines = EditorContent(text).lines;
    final children = <InlineSpan>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final headingLevel = line.headingLevel;
      final lineStyle = headingLevel == null
          ? baseStyle
          : baseStyle.merge(_config.headingStyles[headingLevel]);
      children.add(TextSpan(text: line.value, style: lineStyle));
      if (index < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }
}
