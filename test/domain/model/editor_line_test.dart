import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/src/domain/model/editor_line.dart';

void main() {
  group('EditorLine headingLevel', () {
    test('returns 1 to 6 for valid heading markers', () {
      expect(const EditorLine('# h1').headingLevel, 1);
      expect(const EditorLine('## h2').headingLevel, 2);
      expect(const EditorLine('### h3').headingLevel, 3);
      expect(const EditorLine('#### h4').headingLevel, 4);
      expect(const EditorLine('##### h5').headingLevel, 5);
      expect(const EditorLine('###### h6').headingLevel, 6);
    });

    test('returns null for non heading lines', () {
      expect(const EditorLine('#no-space').headingLevel, isNull);
      expect(const EditorLine('####### too many').headingLevel, isNull);
      expect(const EditorLine('plain text').headingLevel, isNull);
      expect(const EditorLine('').headingLevel, isNull);
    });
  });
}
