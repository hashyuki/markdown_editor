import 'package:flutter/services.dart';

import 'rich_document_text_input_adapter.dart';

typedef RichDocumentEditingValueHandler = void Function(TextEditingValue value);
typedef RichDocumentTextActionHandler = void Function(TextInputAction action);
typedef RichDocumentConnectionClosedHandler = void Function();

class RichDocumentTextInputClient implements TextInputClient {
  RichDocumentTextInputClient({
    required RichDocumentTextInputAdapter textInputAdapter,
    required RichDocumentEditingValueHandler onUpdateEditingValue,
    required RichDocumentTextActionHandler onPerformAction,
    required RichDocumentConnectionClosedHandler onConnectionClosed,
  }) : _textInputAdapter = textInputAdapter,
       _onUpdateEditingValue = onUpdateEditingValue,
       _onPerformAction = onPerformAction,
       _onConnectionClosed = onConnectionClosed;

  final RichDocumentTextInputAdapter _textInputAdapter;
  final RichDocumentEditingValueHandler _onUpdateEditingValue;
  final RichDocumentTextActionHandler _onPerformAction;
  final RichDocumentConnectionClosedHandler _onConnectionClosed;

  @override
  TextEditingValue get currentTextEditingValue => _textInputAdapter.value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _onUpdateEditingValue(value);
  }

  @override
  void performAction(TextInputAction action) {
    _onPerformAction(action);
  }

  @override
  void connectionClosed() {
    _onConnectionClosed();
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void showToolbar() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performSelector(String selectorName) {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}
}
