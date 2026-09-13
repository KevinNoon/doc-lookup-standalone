final _strayTagPattern = RegExp(r'</?[a-zA-Z_][\w-]*(\s+[a-zA-Z_:][\w\-:.]*\s*=\s*"[^"]*")*\s*/?>');

/// Occasionally the model emits stray XML/tag-like artifacts (e.g.
/// `</nuance>`, `<parameter name="...">`) inside a tool-call field's text
/// instead of cleanly separating fields. Strip anything tag-shaped so it
/// never reaches the UI.
String _sanitize(String value) => value.replaceAll(_strayTagPattern, '').trim();

class QuickLookupResult {
  const QuickLookupResult({
    required this.isValidWord,
    required this.definition,
    required this.partOfSpeech,
    required this.shortExample,
  });

  factory QuickLookupResult.fromJson(Map<String, dynamic> json) {
    return QuickLookupResult(
      isValidWord: json['isValidWord'] as bool? ?? true,
      definition: _sanitize(json['definition'] as String? ?? ''),
      partOfSpeech: _sanitize(json['partOfSpeech'] as String? ?? ''),
      shortExample: _sanitize(json['shortExample'] as String? ?? ''),
    );
  }

  final bool isValidWord;
  final String definition;
  final String partOfSpeech;
  final String shortExample;
}

class DeepDiveResult {
  const DeepDiveResult({
    required this.etymology,
    required this.usageExamples,
    required this.nuance,
    required this.contextAnalysis,
  });

  factory DeepDiveResult.fromJson(Map<String, dynamic> json) {
    return DeepDiveResult(
      etymology: _sanitize(json['etymology'] as String? ?? ''),
      usageExamples:
          (json['usageExamples'] as List?)?.map((e) => _sanitize(e as String)).toList() ?? const [],
      nuance: _sanitize(json['nuance'] as String? ?? ''),
      contextAnalysis: _sanitize(json['contextAnalysis'] as String? ?? ''),
    );
  }

  final String etymology;
  final List<String> usageExamples;
  final String nuance;
  final String contextAnalysis;
}

class TranslationResult {
  const TranslationResult({required this.sourceLang, required this.translatedText});

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      sourceLang: json['sourceLang'] as String? ?? '',
      translatedText: _sanitize(json['translatedText'] as String? ?? ''),
    );
  }

  final String sourceLang;
  final String translatedText;
}
