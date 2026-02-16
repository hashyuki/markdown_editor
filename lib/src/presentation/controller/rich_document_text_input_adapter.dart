import 'package:flutter/services.dart';

class RichDocumentTextInputAdapter {
  TextInputConnection? _connection;
  TextEditingValue _value = _emptyValue;

  static const TextEditingValue _emptyValue = TextEditingValue(
    text: '',
    selection: TextSelection.collapsed(offset: 0),
  );

  TextEditingValue get value => _value;

  bool get hasActiveConnection => _connection != null && _connection!.attached;

  bool get isComposing {
    final composing = _value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  String? composingTextOrNull() {
    if (!isComposing || _value.text.isEmpty) {
      return null;
    }
    return _value.text;
  }

  int composingCaretAdvance() {
    if (!isComposing) {
      return 0;
    }
    return _value.selection.extentOffset.clamp(0, _value.text.length);
  }

  void syncConnection({
    required TextInputClient client,
    required bool enabled,
  }) {
    if (enabled) {
      if (_connection == null || !_connection!.attached) {
        _connection = TextInput.attach(
          client,
          const TextInputConfiguration(
            inputType: TextInputType.multiline,
            inputAction: TextInputAction.newline,
            autocorrect: true,
            enableSuggestions: true,
          ),
        );
      }
      _connection!.show();
      resetEditingValue();
      return;
    }
    closeConnection();
  }

  void closeConnection() {
    _connection?.close();
    _connection = null;
  }

  void clearClosedConnection() {
    _connection = null;
  }

  void resetEditingValue() {
    _value = _emptyValue;
    final connection = _connection;
    if (connection != null && connection.attached) {
      connection.setEditingState(_emptyValue);
    }
  }

  void updateFromPlatform(TextEditingValue value) {
    _value = value;
  }
}
