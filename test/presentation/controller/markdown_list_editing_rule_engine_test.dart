import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/text_edit_state.dart';
import 'package:markdown_editor/src/domain/service/line_syntax_parser.dart';
import 'package:markdown_editor/src/domain/service/markdown_list_editing_service.dart';
import 'package:markdown_editor/src/presentation/controller/markdown_list_editing_rule_engine.dart';

void main() {
  group('MarkdownListEditingRuleEngine', () {
    late MarkdownListEditingRuleEngine engine;

    setUp(() {
      final service = MarkdownListEditingService(
        parser: const MarkdownLineSyntaxParser(),
      );
      engine = MarkdownListEditingRuleEngine(service: service);
    });

    test('applies list enter rule for newline insertion', () {
      const oldValue = TextEditState(
        text: '- item',
        selectionStart: 6,
        selectionEnd: 6,
      );
      const newValue = TextEditState(
        text: '- item\n',
        selectionStart: 7,
        selectionEnd: 7,
      );

      final adjusted = engine.apply(oldValue: oldValue, newValue: newValue);

      expect(adjusted.text, '- item\n- ');
      expect(adjusted.selectionEnd, 9);
    });

    test('returns platform edit when event is not enter/backspace', () {
      const oldValue = TextEditState(
        text: '- item',
        selectionStart: 6,
        selectionEnd: 6,
      );
      const newValue = TextEditState(
        text: '- items',
        selectionStart: 7,
        selectionEnd: 7,
      );

      final adjusted = engine.apply(oldValue: oldValue, newValue: newValue);

      expect(adjusted, newValue);
    });
  });
}
