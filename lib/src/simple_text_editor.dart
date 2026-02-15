import 'package:flutter/material.dart';

import 'domain/model/line_syntax.dart';
import 'domain/service/markdown_list_editing_service.dart';
import 'domain/service/line_syntax_parser.dart';
import 'presentation/controller/external_controller_bridge.dart';
import 'presentation/controller/selection_heading_tracker.dart';
import 'presentation/controller/simple_text_editor_config_signature.dart';
import 'presentation/style/line_text_renderer.dart';
import 'presentation/style/line_style_resolver.dart';

class SimpleTextEditorConfig {
  const SimpleTextEditorConfig({
    this.paragraphStyle = _defaultParagraphStyle,
    this.headingStyles = _defaultHeadingStyles,
    this.lineSyntaxParser = const MarkdownLineSyntaxParser(),
    this.lineTextRenderer = const MarkdownLineTextRenderer(),
    this.lineStyleResolver = const HeadingLineStyleResolver(),
  });

  static const TextStyle _defaultParagraphStyle = TextStyle(height: 1);

  static const Map<int, TextStyle> _defaultHeadingStyles = <int, TextStyle>{
    1: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.5),
    2: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.5),
    3: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.5),
    4: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.5),
    5: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.5),
    6: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5),
  };

  final TextStyle? paragraphStyle;
  final Map<int, TextStyle> headingStyles;
  final LineSyntaxParser lineSyntaxParser;
  final LineTextRenderer lineTextRenderer;
  final LineStyleResolver lineStyleResolver;
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
  late final bool _ownsFocusNode;
  late final ExternalControllerBridge _externalControllerBridge;
  late final SelectionHeadingTracker _selectionHeadingTracker;
  late SimpleTextEditorConfigSignature _appliedConfigSignature;

  @override
  void initState() {
    super.initState();
    _controller = _MarkdownTextEditingController(
      text: widget.controller?.text ?? widget.initialText,
      config: widget.config,
    );
    _externalControllerBridge = ExternalControllerBridge(
      internalController: _controller,
      externalController: widget.controller,
    );
    _selectionHeadingTracker = SelectionHeadingTracker(
      controller: _controller,
      parser: widget.config.lineSyntaxParser,
    );
    _appliedConfigSignature = SimpleTextEditorConfigSignature.fromValues(
      paragraphStyle: widget.config.paragraphStyle,
      headingStyles: widget.config.headingStyles,
      lineSyntaxParser: widget.config.lineSyntaxParser,
      lineTextRenderer: widget.config.lineTextRenderer,
      lineStyleResolver: widget.config.lineStyleResolver,
    );
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant SimpleTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _externalControllerBridge.updateExternalController(widget.controller);
    }
    _applyConfigIfNeeded(widget.config);
  }

  void _applyConfigIfNeeded(SimpleTextEditorConfig config) {
    final nextSignature = SimpleTextEditorConfigSignature.fromValues(
      paragraphStyle: config.paragraphStyle,
      headingStyles: config.headingStyles,
      lineSyntaxParser: config.lineSyntaxParser,
      lineTextRenderer: config.lineTextRenderer,
      lineStyleResolver: config.lineStyleResolver,
    );
    if (_appliedConfigSignature == nextSignature) {
      return;
    }
    _controller.updateConfig(config);
    _selectionHeadingTracker.updateParser(config.lineSyntaxParser);
    _appliedConfigSignature = nextSignature;
  }

  TextStyle _paragraphStyleForContext(BuildContext context) {
    final themeStyle =
        Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16);
    return themeStyle.merge(widget.config.paragraphStyle);
  }

  double _cursorHeightForHeading(BuildContext context, int? headingLevel) {
    final paragraphStyle = _paragraphStyleForContext(context);
    final lineStyle = widget.config.lineStyleResolver.resolve(
      paragraphStyle: paragraphStyle,
      syntax: LineSyntax(headingLevel: headingLevel),
      headingStyles: widget.config.headingStyles,
    );
    return lineStyle.fontSize ?? paragraphStyle.fontSize ?? 14;
  }

  @override
  void dispose() {
    _externalControllerBridge.dispose();
    _selectionHeadingTracker.dispose();
    _controller.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paragraphStyle = _paragraphStyleForContext(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: widget.padding,
        child: ValueListenableBuilder<int?>(
          valueListenable: _selectionHeadingTracker,
          builder: (context, headingLevel, _) {
            return TextField(
              key: const Key('simple_text_editor_input'),
              controller: _controller,
              focusNode: _focusNode,
              style: paragraphStyle,
              strutStyle: StrutStyle.disabled,
              cursorHeight: _cursorHeightForHeading(context, headingLevel),
              autofocus: widget.autofocus,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: null,
              maxLines: null,
              expands: true,
              decoration: InputDecoration.collapsed(hintText: widget.hintText),
              onChanged: widget.onChanged,
            );
          },
        ),
      ),
    );
  }
}

class _MarkdownTextEditingController extends TextEditingController {
  _MarkdownTextEditingController({
    super.text,
    required SimpleTextEditorConfig config,
  }) : _config = config,
       _listEditingService = MarkdownListEditingService(
         parser: config.lineSyntaxParser,
       );

  SimpleTextEditorConfig _config;
  final MarkdownListEditingService _listEditingService;

  void updateConfig(SimpleTextEditorConfig config) {
    _config = config;
    _listEditingService.updateParser(config.lineSyntaxParser);
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldSnapshot = EditorTextSnapshot(
      text: super.value.text,
      baseOffset: super.value.selection.baseOffset,
      extentOffset: super.value.selection.extentOffset,
    );
    final newSnapshot = EditorTextSnapshot(
      text: newValue.text,
      baseOffset: newValue.selection.baseOffset,
      extentOffset: newValue.selection.extentOffset,
    );
    final adjustedSnapshot = _listEditingService.applyRules(
      oldValue: oldSnapshot,
      newValue: newSnapshot,
    );
    final adjustedValue = adjustedSnapshot == newSnapshot
        ? newValue
        : TextEditingValue(
            text: adjustedSnapshot.text,
            selection: TextSelection(
              baseOffset: adjustedSnapshot.baseOffset,
              extentOffset: adjustedSnapshot.extentOffset,
            ),
            composing: TextRange.empty,
          );
    super.value = adjustedValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(
      !value.composing.isValid || !withComposing || value.isComposingRangeValid,
      'New TextEditingValue $value has an invalid non-empty composing range '
      '${value.composing}. It is recommended to use a valid composing range, '
      'even for readonly text fields.',
    );
    final baseStyle = (style ?? DefaultTextStyle.of(context).style).merge(
      _config.paragraphStyle,
    );
    final children = <InlineSpan>[];
    final composingRange = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    var lineStart = 0;
    for (var offset = 0; offset <= text.length; offset++) {
      final isLineEnd = offset == text.length || text.codeUnitAt(offset) == 10;
      if (!isLineEnd) {
        continue;
      }

      final lineEnd = offset;
      final lineText = text.substring(lineStart, lineEnd);
      final syntax = _config.lineSyntaxParser.parse(lineText);
      final renderedLineText = _config.lineTextRenderer.render(
        lineText: lineText,
        syntax: syntax,
      );
      final resolvedLineStyle = _config.lineStyleResolver.resolve(
        paragraphStyle: baseStyle,
        syntax: syntax,
        headingStyles: _config.headingStyles,
      );
      children.add(
        _buildComposingTextSpan(
          text: renderedLineText,
          style: resolvedLineStyle,
          segmentStart: lineStart,
          segmentEnd: lineEnd,
          composingRange: composingRange,
        ),
      );

      if (offset < text.length) {
        children.add(
          _buildComposingTextSpan(
            text: '\n',
            style: baseStyle,
            segmentStart: offset,
            segmentEnd: offset + 1,
            composingRange: composingRange,
          ),
        );
        lineStart = offset + 1;
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _buildComposingTextSpan({
    required String text,
    required TextStyle style,
    required int segmentStart,
    required int segmentEnd,
    required TextRange? composingRange,
  }) {
    if (text.isEmpty || composingRange == null) {
      return TextSpan(text: text, style: style);
    }
    final overlapStart = segmentStart > composingRange.start
        ? segmentStart
        : composingRange.start;
    final overlapEnd = segmentEnd < composingRange.end
        ? segmentEnd
        : composingRange.end;
    if (overlapStart >= overlapEnd) {
      return TextSpan(text: text, style: style);
    }

    final localOverlapStart = overlapStart - segmentStart;
    final localOverlapEnd = overlapEnd - segmentStart;
    final mergedDecoration = TextDecoration.combine([
      if (style.decoration != null) style.decoration!,
      TextDecoration.underline,
    ]);
    final composingStyle = style.copyWith(decoration: mergedDecoration);
    final children = <InlineSpan>[];

    if (localOverlapStart > 0) {
      children.add(
        TextSpan(text: text.substring(0, localOverlapStart), style: style),
      );
    }
    children.add(
      TextSpan(
        text: text.substring(localOverlapStart, localOverlapEnd),
        style: composingStyle,
      ),
    );
    if (localOverlapEnd < text.length) {
      children.add(
        TextSpan(text: text.substring(localOverlapEnd), style: style),
      );
    }

    return TextSpan(style: style, children: children);
  }
}
