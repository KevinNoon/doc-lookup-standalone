import 'package:doc_lookup/shared/utils/clean_selected_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips trailing punctuation dragged in by selection', () {
    expect(cleanSelectedText("reformation',"), 'reformation');
  });

  test('strips leading punctuation', () {
    expect(cleanSelectedText('"Reformation'), 'Reformation');
  });

  test('preserves internal hyphens and apostrophes', () {
    expect(cleanSelectedText('well-known'), 'well-known');
    expect(cleanSelectedText("don't"), "don't");
  });

  test('trims surrounding whitespace along with punctuation', () {
    expect(cleanSelectedText('  "word."  '), 'word');
  });

  test('returns empty string for punctuation-only selections', () {
    expect(cleanSelectedText('—,.'), '');
  });
}
