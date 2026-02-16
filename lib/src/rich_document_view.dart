import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/use_case/edit_rich_document_use_case.dart';
import 'domain/model/rich_document.dart';
import 'domain/model/rich_document_selection.dart';
import 'presentation/controller/editor_history.dart';
import 'presentation/controller/rich_document_input_controller.dart';
import 'presentation/controller/rich_document_text_input_adapter.dart';
import 'presentation/controller/rich_document_text_input_client.dart';
import 'presentation/service/block_presentation_policy.dart';
import 'presentation/service/rich_text_layout_service.dart';

class RichDocumentView extends StatefulWidget {
  const RichDocumentView({
    super.key,
    required this.document,
    this.padding = const EdgeInsets.all(8),
    this.enableKeyboardSelection = false,
    this.enableKeyboardEditing = false,
    this.selection,
    this.onSelectionChanged,
    this.onDocumentChanged,
    this.inputController = const RichDocumentInputController(),
    this.layoutService = const RichTextLayoutService(),
    this.presentationPolicy = const BlockPresentationPolicy(),
    this.historyBuilder = _defaultHistoryBuilder,
  });

  final RichDocument document;
  final EdgeInsetsGeometry padding;
  final bool enableKeyboardSelection;
  final bool enableKeyboardEditing;
  final RichSelection? selection;
  final ValueChanged<RichSelection>? onSelectionChanged;
  final ValueChanged<RichDocument>? onDocumentChanged;
  final RichDocumentInputController inputController;
  final RichTextLayoutService layoutService;
  final BlockPresentationPolicy presentationPolicy;
  final EditorHistory Function() historyBuilder;

  static EditorHistory _defaultHistoryBuilder() =>
      EditorHistory(maxEntries: 200);

  @override
  State<RichDocumentView> createState() => _RichDocumentViewState();
}

class _RichDocumentViewState extends State<RichDocumentView> {
  static const Key _focusKey = Key('rich_document_view_focus');

  final FocusNode _focusNode = FocusNode();
  RichTextPosition? _dragAnchor;
  RichDocumentEditorState? _stateCache;
  final Map<String, _BlockHitTarget> _blockHitTargets =
      <String, _BlockHitTarget>{};
  late final EditorHistory _history;
  final RichDocumentTextInputAdapter _textInputAdapter =
      RichDocumentTextInputAdapter();
  late final RichDocumentTextInputClient _textInputClient;
  RichDocument? _lastLocallyEmittedDocument;
  static final Set<LogicalKeyboardKey> _shortcutKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  };

  @override
  void initState() {
    super.initState();
    _history = widget.historyBuilder();
    _textInputClient = RichDocumentTextInputClient(
      textInputAdapter: _textInputAdapter,
      onUpdateEditingValue: _handlePlatformEditingValue,
      onPerformAction: _handlePlatformPerformAction,
      onConnectionClosed: _handleTextConnectionClosed,
    );
    _stateCache = _initialState(widget.document, widget.selection);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RichDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.selection != widget.selection) {
      final isLocalEcho =
          _lastLocallyEmittedDocument != null &&
          widget.document == _lastLocallyEmittedDocument;
      if (oldWidget.document != widget.document && !isLocalEcho) {
        _history.reset();
      }
      if (isLocalEcho) {
        _lastLocallyEmittedDocument = null;
      }
      final previous = _stateCache;
      _stateCache = RichDocumentEditorState(
        document: widget.document,
        selection: widget.selection ?? previous?.selection ?? _selectionAtTop,
        preferredColumn: previous?.preferredColumn,
      );
    }
    _updateTextInputConnection();
  }

  @override
  void dispose() {
    _textInputAdapter.closeConnection();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    _updateTextInputConnection();
    setState(() {});
  }

  bool get _shouldEnableTextInput =>
      widget.enableKeyboardSelection &&
      widget.enableKeyboardEditing &&
      _focusNode.hasFocus;

  RichSelection get _selectionAtTop => RichSelection.collapsed(
    RichTextPosition(blockId: widget.document.blocks.first.id, offset: 0),
  );

  RichDocumentEditorState _initialState(
    RichDocument document,
    RichSelection? selection,
  ) {
    return RichDocumentEditorState(
      document: document,
      selection:
          selection ??
          RichSelection.collapsed(
            RichTextPosition(blockId: document.blocks.first.id, offset: 0),
          ),
    );
  }

  RichDocumentEditorState get _state {
    final cache = _stateCache;
    final document = cache?.document ?? widget.document;
    final fallback = RichSelection.collapsed(
      RichTextPosition(blockId: document.blocks.first.id, offset: 0),
    );
    final selection = cache?.selection ?? widget.selection ?? fallback;
    return widget.inputController.normalize(
      RichDocumentEditorState(
        document: document,
        selection: selection,
        preferredColumn: cache?.preferredColumn,
      ),
    );
  }

  void _emitState(
    RichDocumentEditorState next, {
    bool resetTextInput = true,
    bool notifyListeners = true,
    bool recordHistory = true,
  }) {
    final previous = _stateCache;
    if (recordHistory && previous != null) {
      _history.pushIfDocumentChanged(previous: previous, next: next);
    }
    setState(() {
      _stateCache = next;
    });
    if (resetTextInput) {
      _textInputAdapter.resetEditingValue();
    }
    if (notifyListeners) {
      _lastLocallyEmittedDocument = next.document;
      widget.onSelectionChanged?.call(next.selection);
      widget.onDocumentChanged?.call(next.document);
    }
  }

  bool _applyUndo() {
    final next = _history.undo(_state);
    if (next == null) {
      return false;
    }
    _emitState(next, recordHistory: false);
    return true;
  }

  bool _applyRedo() {
    final next = _history.redo(_state);
    if (next == null) {
      return false;
    }
    _emitState(next, recordHistory: false);
    return true;
  }

  void _updateTextInputConnection() {
    _textInputAdapter.syncConnection(
      client: _textInputClient,
      enabled: _shouldEnableTextInput,
    );
  }

  @override
  Widget build(BuildContext context) {
    _blockHitTargets.clear();
    final themeBody =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final bodyStyle = themeBody.copyWith(height: 1.0);
    final state = _state;
    final document = state.document;
    final selection = state.selection;

    final content = SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < document.blocks.length; i++)
            () {
              final block = document.blocks[i];
              final nextBlock = i + 1 < document.blocks.length
                  ? document.blocks[i + 1]
                  : null;
              final bottomSpacing = widget.presentationPolicy.blockSpacingAfter(
                block,
                nextBlock,
              );
              return Padding(
                padding: EdgeInsets.only(bottom: bottomSpacing),
                child: _buildBlock(
                  context,
                  document: document,
                  block: block,
                  bodyStyle: bodyStyle,
                  selection: selection,
                ),
              );
            }(),
        ],
      ),
    );

    if (!widget.enableKeyboardSelection) {
      return content;
    }

    return Focus(
      key: _focusKey,
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _onKeyEvent(event),
      child: Listener(
        onPointerMove: _onPointerMove,
        onPointerUp: (_) => _dragAnchor = null,
        onPointerCancel: (_) => _dragAnchor = null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onCanvasTapDown,
          onTap: _focusNode.requestFocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8)),
            ],
          ),
        ),
      ),
    );
  }

  void _onCanvasTapDown(TapDownDetails details) {
    if (!widget.enableKeyboardEditing) {
      _focusNode.requestFocus();
      return;
    }
    final position = _positionForGlobalDrag(details.globalPosition);
    if (position != null) {
      final next = widget.inputController.collapseSelection(_state, position);
      _emitState(next);
    }
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final isShortcut = _containsAny(pressedKeys, _shortcutKeys);
    final isShift =
        pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight);
    if (_shouldEnableTextInput &&
        _textInputAdapter.isComposing &&
        !isShortcut) {
      return KeyEventResult.ignored;
    }
    if (widget.enableKeyboardEditing &&
        isShortcut &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      final applied = isShift ? _applyRedo() : _applyUndo();
      return applied ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (widget.enableKeyboardEditing &&
        isShortcut &&
        event.logicalKey == LogicalKeyboardKey.keyY) {
      final applied = _applyRedo();
      return applied ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (isShortcut && event.logicalKey == LogicalKeyboardKey.keyC) {
      final selectedText = widget.inputController.selectedPlainText(_state);
      if (selectedText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: selectedText));
      }
      return KeyEventResult.handled;
    }
    if (widget.enableKeyboardEditing &&
        isShortcut &&
        event.logicalKey == LogicalKeyboardKey.keyV) {
      _pasteFromClipboard();
      return KeyEventResult.handled;
    }
    final next = widget.inputController.handleKeyDown(
      _state,
      event,
      enableEditing: widget.enableKeyboardEditing,
      pressedKeys: pressedKeys,
      allowCharacterInput: !_shouldEnableTextInput,
    );
    if (next != null) {
      _emitState(next);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePlatformEditingValue(TextEditingValue value) {
    setState(() {
      _textInputAdapter.updateFromPlatform(value);
    });
    final composing = value.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    if (isComposing) {
      if (value.text.isNotEmpty && !_state.selection.isCollapsed) {
        final next = widget.inputController.deleteSelection(_state);
        _emitState(
          next,
          resetTextInput: false,
          notifyListeners: false,
          recordHistory: false,
        );
      }
      return;
    }
    final text = value.text;
    if (text.isEmpty) {
      return;
    }
    final next = widget.inputController.pastePlainText(_state, text);
    _emitState(next);
  }

  void _handlePlatformPerformAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      final next = widget.inputController.handleKeyDown(
        _state,
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
        ),
        enableEditing: widget.enableKeyboardEditing,
        pressedKeys: const <LogicalKeyboardKey>{},
      );
      if (next != null) {
        _emitState(next);
      }
    }
  }

  void _handleTextConnectionClosed() {
    _textInputAdapter.clearClosedConnection();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    final next = widget.inputController.pastePlainText(_state, text);
    _emitState(next);
  }

  bool _containsAny(
    Set<LogicalKeyboardKey> pressedKeys,
    Set<LogicalKeyboardKey> targetKeys,
  ) {
    for (final key in targetKeys) {
      if (pressedKeys.contains(key)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildBlock(
    BuildContext context, {
    required RichDocument document,
    required BlockNode block,
    required TextStyle bodyStyle,
    required RichSelection selection,
  }) {
    final isActiveBlock =
        selection.base.blockId == block.id ||
        selection.extent.blockId == block.id;
    final range = _selectionRangeInBlock(document, selection, block.id);
    final caretOffset =
        selection.isCollapsed && selection.extent.blockId == block.id
        ? selection.extent.offset
        : null;
    final isEditingBlock =
        widget.enableKeyboardEditing &&
        _focusNode.hasFocus &&
        selection.extent.blockId == block.id;

    final decoration = isActiveBlock
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          )
        : null;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: decoration ?? const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: _buildBlockContent(
            context,
            document: document,
            block: block,
            bodyStyle: bodyStyle,
            range: range,
            caretOffset: caretOffset,
            isEditingBlock: isEditingBlock,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockContent(
    BuildContext context, {
    required RichDocument document,
    required BlockNode block,
    required TextStyle bodyStyle,
    required _BlockSelectionRange? range,
    required int? caretOffset,
    required bool isEditingBlock,
  }) {
    final markdownPrefix = isEditingBlock
        ? widget.presentationPolicy.editingMarkdownPrefixForBlock(block)
        : '';
    final editingStyle = widget.presentationPolicy.textStyleForBlock(
      bodyStyle,
      block,
    );

    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 1;
        return _buildTappableText(
          context,
          block: block,
          textStyle: isEditingBlock
              ? editingStyle
              : widget.presentationPolicy.headingRenderStyle(bodyStyle, level),
          range: range,
          caretOffset: caretOffset,
          markdownPrefix: markdownPrefix,
          showMarkdownSyntax: isEditingBlock,
          hiddenLeadingChars: 0,
        );
      case BlockType.bulletListItem:
        final hiddenLeadingChars = widget.presentationPolicy
            .hiddenLeadingCharsForBullet(block);
        return _ListRow(
          marker: '•',
          indent: block.indent,
          markerStyle: bodyStyle.copyWith(height: 1.0),
          markerWidth: 16,
          child: _buildTappableText(
            context,
            block: block,
            textStyle: bodyStyle,
            range: range,
            caretOffset: caretOffset,
            markdownPrefix: '',
            showMarkdownSyntax: false,
            hiddenLeadingChars: hiddenLeadingChars,
          ),
        );
      case BlockType.orderedListItem:
        final orderedNumber = widget.presentationPolicy
            .orderedDisplayNumberInDocument(document, block);
        final markerText = '$orderedNumber.';
        final hiddenLeadingChars = widget.presentationPolicy
            .hiddenLeadingCharsForOrdered(block);
        final markerStyle = bodyStyle.copyWith(height: 1.0);
        final markerWidth = widget.presentationPolicy.orderedMarkerWidth(
          context: context,
          markerText: markerText,
          style: markerStyle,
        );
        return _ListRow(
          marker: markerText,
          indent: block.indent,
          markerStyle: markerStyle,
          markerWidth: markerWidth,
          child: _buildTappableText(
            context,
            block: block,
            textStyle: bodyStyle,
            range: range,
            caretOffset: caretOffset,
            markdownPrefix: '',
            showMarkdownSyntax: false,
            hiddenLeadingChars: hiddenLeadingChars,
          ),
        );
      case BlockType.quote:
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF9AA3B2), width: 3),
            ),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: _buildTappableText(
            context,
            block: block,
            textStyle: editingStyle.copyWith(fontStyle: FontStyle.italic),
            range: range,
            caretOffset: caretOffset,
            markdownPrefix: markdownPrefix,
            showMarkdownSyntax: isEditingBlock,
            hiddenLeadingChars: 0,
          ),
        );
      case BlockType.codeBlock:
      case BlockType.table:
      case BlockType.paragraph:
        return _buildTappableText(
          context,
          block: block,
          textStyle: editingStyle,
          range: range,
          caretOffset: caretOffset,
          markdownPrefix: markdownPrefix,
          showMarkdownSyntax: isEditingBlock,
          hiddenLeadingChars: 0,
        );
    }
  }

  Widget _buildTappableText(
    BuildContext context, {
    required BlockNode block,
    required TextStyle textStyle,
    required _BlockSelectionRange? range,
    required int? caretOffset,
    required String markdownPrefix,
    required bool showMarkdownSyntax,
    required int hiddenLeadingChars,
  }) {
    final plainText = block.plainText;
    final boundedHiddenLeadingChars = hiddenLeadingChars.clamp(
      0,
      plainText.length,
    );
    final visibleText = plainText.substring(boundedHiddenLeadingChars);
    var visualText = '$markdownPrefix$visibleText';
    final visualLeadingOffset = markdownPrefix.length;
    final logicalToVisualOffsetDelta =
        visualLeadingOffset - boundedHiddenLeadingChars;
    final composingText = _composingTextForBlock(block.id);
    final hasComposingPreview = composingText != null && caretOffset != null;
    final composingCaretAdvance = hasComposingPreview
        ? _composingCaretAdvanceForBlock(block.id)
        : 0;
    if (hasComposingPreview) {
      final visualCaretOffset = (caretOffset + logicalToVisualOffsetDelta)
          .clamp(0, visualText.length);
      visualText =
          '${visualText.substring(0, visualCaretOffset)}$composingText${visualText.substring(visualCaretOffset)}';
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _blockHitTargets[block.id] = _BlockHitTarget(
          context: context,
          blockId: block.id,
          text: visualText,
          textLength: block.textLength,
          textStyle: textStyle,
          maxWidth: constraints.maxWidth,
          logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
        );
        final caretRect = widget.layoutService.caretRectForOffset(
          context: context,
          text: visualText,
          textLength: plainText.length + (composingText?.length ?? 0),
          textStyle: textStyle,
          maxWidth: constraints.maxWidth,
          offset: caretOffset == null
              ? null
              : caretOffset + composingCaretAdvance,
          logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
        );
        final hasActiveTextInputConnection =
            _textInputAdapter.hasActiveConnection;
        final showCaret =
            caretRect != null &&
            widget.enableKeyboardSelection &&
            (_focusNode.hasFocus || hasActiveTextInputConnection);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _onBlockTapDown(
            context,
            block: block,
            details: details,
            textStyle: textStyle,
            maxWidth: constraints.maxWidth,
            visualText: visualText,
            logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
          ),
          onPanStart: (details) => _onBlockPanStart(
            context,
            block: block,
            details: details,
            textStyle: textStyle,
            maxWidth: constraints.maxWidth,
            visualText: visualText,
            logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
          ),
          onPanUpdate: (details) => _onBlockPanUpdate(
            context,
            block: block,
            details: details,
            textStyle: textStyle,
            maxWidth: constraints.maxWidth,
            visualText: visualText,
            logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
          ),
          onPanEnd: (_) => _dragAnchor = null,
          onPanCancel: () => _dragAnchor = null,
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RichText(
                  text: TextSpan(
                    style: textStyle,
                    children:
                        showMarkdownSyntax ||
                            boundedHiddenLeadingChars > 0 ||
                            hasComposingPreview
                        ? _buildPlainTextSpans(
                            visualText,
                            textStyle,
                            range: range,
                            logicalToVisualOffsetDelta:
                                logicalToVisualOffsetDelta,
                          )
                        : _buildInlineSpans(
                            block.inlines,
                            textStyle,
                            range: range,
                          ),
                  ),
                ),
                if (showCaret)
                  Positioned(
                    left: caretRect.left,
                    top: math.max(0, caretRect.top),
                    child: Container(
                      key: const Key('rich_document_caret'),
                      width: 2.2,
                      height: caretRect.height,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _composingTextForBlock(String blockId) {
    if (!_textInputAdapter.isComposing) {
      return null;
    }
    if (_state.selection.extent.blockId != blockId) {
      return null;
    }
    return _textInputAdapter.composingTextOrNull();
  }

  int _composingCaretAdvanceForBlock(String blockId) {
    if (!_textInputAdapter.isComposing) {
      return 0;
    }
    if (_state.selection.extent.blockId != blockId) {
      return 0;
    }
    return _textInputAdapter.composingCaretAdvance();
  }

  void _onBlockTapDown(
    BuildContext context, {
    required BlockNode block,
    required TapDownDetails details,
    required TextStyle textStyle,
    required double maxWidth,
    required String visualText,
    required int logicalToVisualOffsetDelta,
  }) {
    final offset = widget.layoutService.textOffsetFromLocalPosition(
      context: context,
      text: visualText,
      textLength: block.textLength,
      localPosition: details.localPosition,
      textStyle: textStyle,
      maxWidth: maxWidth,
      logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
    );
    final position = RichTextPosition(blockId: block.id, offset: offset);
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final shiftPressed =
        pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.shiftRight);
    final next = shiftPressed
        ? widget.inputController.selectRange(
            _state,
            base: _state.selection.base,
            extent: position,
            preferredColumn: position.offset,
          )
        : widget.inputController.collapseSelection(_state, position);
    _emitState(next);
    if (widget.enableKeyboardSelection) {
      _focusNode.requestFocus();
    }
  }

  void _onBlockPanStart(
    BuildContext context, {
    required BlockNode block,
    required DragStartDetails details,
    required TextStyle textStyle,
    required double maxWidth,
    required String visualText,
    required int logicalToVisualOffsetDelta,
  }) {
    final offset = widget.layoutService.textOffsetFromLocalPosition(
      context: context,
      text: visualText,
      textLength: block.textLength,
      localPosition: details.localPosition,
      textStyle: textStyle,
      maxWidth: maxWidth,
      logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
    );
    final anchor = RichTextPosition(blockId: block.id, offset: offset);
    _dragAnchor = anchor;
    _emitState(widget.inputController.collapseSelection(_state, anchor));
    if (widget.enableKeyboardSelection) {
      _focusNode.requestFocus();
    }
  }

  void _onBlockPanUpdate(
    BuildContext context, {
    required BlockNode block,
    required DragUpdateDetails details,
    required TextStyle textStyle,
    required double maxWidth,
    required String visualText,
    required int logicalToVisualOffsetDelta,
  }) {
    final anchor = _dragAnchor;
    if (anchor == null) {
      return;
    }
    _updateDragSelectionFromGlobal(
      details.globalPosition,
      fallback: RichTextPosition(
        blockId: block.id,
        offset: widget.layoutService.textOffsetFromLocalPosition(
          context: context,
          text: visualText,
          textLength: block.textLength,
          localPosition: details.localPosition,
          textStyle: textStyle,
          maxWidth: maxWidth,
          logicalToVisualOffsetDelta: logicalToVisualOffsetDelta,
        ),
      ),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragAnchor == null) {
      return;
    }
    _updateDragSelectionFromGlobal(event.position);
  }

  void _updateDragSelectionFromGlobal(
    Offset globalPosition, {
    RichTextPosition? fallback,
  }) {
    final anchor = _dragAnchor;
    if (anchor == null) {
      return;
    }
    final extent = _positionForGlobalDrag(globalPosition) ?? fallback ?? anchor;
    _emitState(
      widget.inputController.selectRange(
        _state,
        base: anchor,
        extent: extent,
        preferredColumn: extent.offset,
      ),
    );
  }

  RichTextPosition? _positionForGlobalDrag(Offset globalPosition) {
    _BlockHitTarget? best;
    var bestDistance = double.infinity;
    var bestCenterDistance = double.infinity;
    final staleBlockIds = <String>[];
    for (final entry in _blockHitTargets.entries) {
      final target = entry.value;
      final box = _safeRenderBox(target.context);
      if (box == null) {
        staleBlockIds.add(entry.key);
        continue;
      }
      final local = box.globalToLocal(globalPosition);
      final yDistance = _distanceToRange(local.dy, 0, box.size.height);
      final centerDistance = (local.dy - (box.size.height / 2)).abs();
      if (yDistance < bestDistance ||
          (yDistance == bestDistance && centerDistance < bestCenterDistance)) {
        bestDistance = yDistance;
        bestCenterDistance = centerDistance;
        best = target;
      }
    }
    for (final blockId in staleBlockIds) {
      _blockHitTargets.remove(blockId);
    }
    if (best == null) {
      return null;
    }
    final box = _safeRenderBox(best.context);
    if (box == null) {
      return null;
    }
    final local = box.globalToLocal(globalPosition);
    final offset = widget.layoutService.textOffsetFromLocalPosition(
      context: best.context,
      text: best.text,
      textLength: best.textLength,
      localPosition: local,
      textStyle: best.textStyle,
      maxWidth: best.maxWidth,
      logicalToVisualOffsetDelta: best.logicalToVisualOffsetDelta,
    );
    return RichTextPosition(blockId: best.blockId, offset: offset);
  }

  RenderBox? _safeRenderBox(BuildContext context) {
    if (!mounted || !context.mounted) {
      return null;
    }
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) {
        return null;
      }
      if (!renderObject.attached || !renderObject.hasSize) {
        return null;
      }
      return renderObject;
    } catch (_) {
      return null;
    }
  }

  double _distanceToRange(double value, double min, double max) {
    if (value < min) {
      return min - value;
    }
    if (value > max) {
      return value - max;
    }
    return 0;
  }

  List<InlineSpan> _buildInlineSpans(
    List<InlineText> inlines,
    TextStyle baseStyle, {
    _BlockSelectionRange? range,
  }) {
    if (inlines.isEmpty) {
      return const <InlineSpan>[TextSpan(text: '')];
    }

    final highlight = Colors.lightBlue.withValues(alpha: 0.25);
    var globalOffset = 0;
    return inlines
        .map((inline) {
          final start = globalOffset;
          final end = start + inline.text.length;
          globalOffset = end;
          if (range == null) {
            return TextSpan(text: inline.text, style: baseStyle);
          }
          final selectedStart = start < range.start ? range.start : start;
          final selectedEnd = end > range.end ? range.end : end;
          if (selectedStart >= selectedEnd) {
            return TextSpan(text: inline.text, style: baseStyle);
          }

          final before = inline.text.substring(0, selectedStart - start);
          final selected = inline.text.substring(
            selectedStart - start,
            selectedEnd - start,
          );
          final after = inline.text.substring(selectedEnd - start);
          return TextSpan(
            children: [
              if (before.isNotEmpty) TextSpan(text: before, style: baseStyle),
              if (selected.isNotEmpty)
                TextSpan(
                  text: selected,
                  style: baseStyle.copyWith(backgroundColor: highlight),
                ),
              if (after.isNotEmpty) TextSpan(text: after, style: baseStyle),
            ],
          );
        })
        .toList(growable: false);
  }

  List<InlineSpan> _buildPlainTextSpans(
    String text,
    TextStyle baseStyle, {
    required _BlockSelectionRange? range,
    required int logicalToVisualOffsetDelta,
  }) {
    if (text.isEmpty) {
      return const <InlineSpan>[TextSpan(text: '')];
    }
    if (range == null) {
      return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
    }

    final highlight = Colors.lightBlue.withValues(alpha: 0.25);
    final selectedStart = (range.start + logicalToVisualOffsetDelta).clamp(
      0,
      text.length,
    );
    final selectedEnd = (range.end + logicalToVisualOffsetDelta).clamp(
      0,
      text.length,
    );
    final before = text.substring(0, selectedStart);
    final selected = text.substring(selectedStart, selectedEnd);
    final after = text.substring(selectedEnd);
    return <InlineSpan>[
      if (before.isNotEmpty) TextSpan(text: before, style: baseStyle),
      if (selected.isNotEmpty)
        TextSpan(
          text: selected,
          style: baseStyle.copyWith(backgroundColor: highlight),
        ),
      if (after.isNotEmpty) TextSpan(text: after, style: baseStyle),
    ];
  }

  _BlockSelectionRange? _selectionRangeInBlock(
    RichDocument document,
    RichSelection selection,
    String blockId,
  ) {
    if (selection.isCollapsed) {
      return null;
    }

    final base = selection.base;
    final extent = selection.extent;
    final baseIndex = document.indexOfBlock(base.blockId);
    final extentIndex = document.indexOfBlock(extent.blockId);
    if (baseIndex == -1 || extentIndex == -1) {
      return null;
    }

    final start =
        baseIndex < extentIndex ||
            (baseIndex == extentIndex && base.offset <= extent.offset)
        ? base
        : extent;
    final end = identical(start, base) ? extent : base;
    final blockIndex = document.indexOfBlock(blockId);
    if (blockIndex < document.indexOfBlock(start.blockId) ||
        blockIndex > document.indexOfBlock(end.blockId)) {
      return null;
    }

    final block = document.blockById(blockId);
    var rangeStart = 0;
    var rangeEnd = block.textLength;
    if (blockId == start.blockId) {
      rangeStart = start.offset;
    }
    if (blockId == end.blockId) {
      rangeEnd = end.offset;
    }
    if (rangeStart >= rangeEnd) {
      return null;
    }
    return _BlockSelectionRange(start: rangeStart, end: rangeEnd);
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.marker,
    required this.indent,
    required this.markerStyle,
    required this.markerWidth,
    required this.child,
  });

  final String marker;
  final int indent;
  final TextStyle markerStyle;
  final double markerWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final leftSpace = indent * markerWidth;
    return Padding(
      padding: EdgeInsets.only(left: leftSpace),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: markerWidth,
            child: Text(marker, style: markerStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BlockSelectionRange {
  const _BlockSelectionRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _BlockHitTarget {
  const _BlockHitTarget({
    required this.context,
    required this.blockId,
    required this.text,
    required this.textLength,
    required this.textStyle,
    required this.maxWidth,
    required this.logicalToVisualOffsetDelta,
  });

  final BuildContext context;
  final String blockId;
  final String text;
  final int textLength;
  final TextStyle textStyle;
  final double maxWidth;
  final int logicalToVisualOffsetDelta;
}
