import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../settings/data/settings_repository.dart';
import '../domain/lookup_result.dart';

part 'ai_lookup_repository.g.dart';

const _quickModel = 'gemini-3.5-flash-lite';
const _deepModel = 'gemini-3.5-flash';
const _maxContextSnippetChars = 1500;

// Gemini's stronger models (used for deep dive) return these fairly often
// under normal load — they're transient server-side overload/rate-limit
// responses, not request errors, so worth a couple of automatic retries
// before surfacing anything to the user.
const _maxRetries = 2;
const _retryableStatusCodes = {429, 500, 502, 503, 504};

const _quickLookupSystemPrompt =
    'You are a dictionary lookup assistant embedded in a document reader. '
    'Given a selected word/phrase and the surrounding context, respond with a short, '
    'dictionary-style definition, its part of speech, and one brief example sentence. '
    'Keep every field terse — this is a quick-glance result, not an essay. '
    'If the selection is not a real word or phrase, set isValidWord to false and leave the '
    'other fields minimal rather than inventing a definition.';

const _quickLookupSchema = {
  'type': 'OBJECT',
  'properties': {
    'isValidWord': {
      'type': 'BOOLEAN',
      'description': 'False if the selection is not a real word/phrase (garbage selection).',
    },
    'definition': {'type': 'STRING'},
    'partOfSpeech': {'type': 'STRING'},
    'shortExample': {'type': 'STRING'},
  },
  'required': ['isValidWord', 'definition', 'partOfSpeech', 'shortExample'],
};

const _deepDiveSystemPrompt =
    'You are a dictionary lookup assistant embedded in a document reader, now providing a '
    'deeper explanation the user explicitly asked for after seeing a quick definition. '
    "Use the provided surrounding paragraph to ground contextAnalysis in how the word is "
    'actually being used here, not just its generic meaning. Keep each field focused and '
    'skimmable — separate fields, not one long paragraph.';

const _deepDiveSchema = {
  'type': 'OBJECT',
  'properties': {
    'etymology': {'type': 'STRING'},
    'usageExamples': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'},
    },
    'nuance': {
      'type': 'STRING',
      'description': 'Connotation, register, or common confusions with similar words.',
    },
    'contextAnalysis': {
      'type': 'STRING',
      'description': 'What the word specifically means given the provided surrounding text.',
    },
  },
  'required': ['etymology', 'usageExamples', 'nuance', 'contextAnalysis'],
};

const _translateSystemPrompt =
    'You are a translation assistant embedded in a document reader. Detect the source '
    'language of the given text and respond with the source language code and an accurate, '
    'natural-sounding translation into the requested target language. The text may be a '
    'single word or short phrase, which can be ambiguous in isolation (e.g. spelled the same '
    'in multiple languages) — use the surrounding context, when provided, to determine which '
    'language and sense is actually being used in the document, rather than guessing from the '
    'word alone.';

const _translateSchema = {
  'type': 'OBJECT',
  'properties': {
    'sourceLang': {'type': 'STRING', 'description': "BCP-47 language code, e.g. 'fr', 'ja'."},
    'translatedText': {'type': 'STRING'},
  },
  'required': ['sourceLang', 'translatedText'],
};

String _truncateContext(String contextSnippet) {
  return contextSnippet.length > _maxContextSnippetChars
      ? contextSnippet.substring(0, _maxContextSnippetChars)
      : contextSnippet;
}

/// Calls Google's Gemini API directly from the client using a user-supplied
/// free API key (see [SettingsRepository]) — there's no shared secret to
/// protect here, unlike the cloud-synced app's Cloudflare Worker proxy, so
/// no server-side proxy is needed for this standalone build.
class AiLookupRepository {
  AiLookupRepository(this._settings);

  final SettingsRepository _settings;

  Future<String> _apiKey() async {
    final key = await _settings.getGeminiApiKey();
    if (key == null || key.isEmpty) {
      throw StateError(
        'No Gemini API key set. Add a free key from Google AI Studio in Settings to use AI lookup.',
      );
    }
    return key;
  }

  /// [fallbackModel], if given, is tried (with its own retry budget) when
  /// [model] exhausts its retries and is still failing with a retryable
  /// status — deep dive's `gemini-3.5-flash` can be under sustained enough
  /// demand that a few quick retries against the *same* model never
  /// succeed, so falling back to the lite model (already reliable for
  /// quick lookups) trades some depth for actually returning something.
  Future<Map<String, dynamic>> _generate({
    required String model,
    String? fallbackModel,
    required String systemPrompt,
    required String userContent,
    required Map<String, dynamic> schema,
  }) async {
    final apiKey = await _apiKey();
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': userContent},
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'generationConfig': {'responseMimeType': 'application/json', 'responseSchema': schema},
    });

    Future<http.Response> attempt(String modelName) async {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');
      late http.Response response;
      for (var attempt = 0; ; attempt++) {
        response = await http.post(
          uri,
          headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
          body: body,
        );
        if (response.statusCode == 200) break;
        if (attempt >= _maxRetries || !_retryableStatusCodes.contains(response.statusCode)) break;
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
      return response;
    }

    var response = await attempt(model);
    if (response.statusCode != 200 && fallbackModel != null && _retryableStatusCodes.contains(response.statusCode)) {
      response = await attempt(fallbackModel);
    }
    if (response.statusCode != 200) {
      throw StateError('Gemini request failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    String? text;
    if (candidates != null && candidates.isNotEmpty) {
      final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        text = (parts.first as Map<String, dynamic>)['text'] as String?;
      }
    }
    if (text == null) {
      throw StateError('Gemini did not return a structured result.');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<QuickLookupResult> quickLookup({required String word, required String contextSnippet}) async {
    final json = await _generate(
      model: _quickModel,
      systemPrompt: _quickLookupSystemPrompt,
      userContent: 'Word/phrase: "$word"\n\nSurrounding context:\n${_truncateContext(contextSnippet)}',
      schema: _quickLookupSchema,
    );
    return QuickLookupResult.fromJson(json);
  }

  Future<DeepDiveResult> deepDive({
    required String word,
    required String contextSnippet,
    String? quickDefinition,
  }) async {
    final userContent = [
      'Word/phrase: "$word"',
      if (quickDefinition != null) 'Quick definition already shown to the user: $quickDefinition',
      'Surrounding context:\n${_truncateContext(contextSnippet)}',
    ].join('\n\n');
    final json = await _generate(
      model: _deepModel,
      fallbackModel: _quickModel,
      systemPrompt: _deepDiveSystemPrompt,
      userContent: userContent,
      schema: _deepDiveSchema,
    );
    return DeepDiveResult.fromJson(json);
  }

  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    required String contextSnippet,
  }) async {
    final userContent = [
      'Translate the following text into "$targetLang": "$text"',
      if (contextSnippet.isNotEmpty)
        'Surrounding context it appears in (use this to disambiguate the word/language if needed):\n${_truncateContext(contextSnippet)}',
    ].join('\n\n');
    final json = await _generate(
      model: _quickModel,
      systemPrompt: _translateSystemPrompt,
      userContent: userContent,
      schema: _translateSchema,
    );
    return TranslationResult.fromJson(json);
  }
}

@riverpod
Future<AiLookupRepository> aiLookupRepository(Ref ref) async {
  return AiLookupRepository(await ref.watch(settingsRepositoryProvider.future));
}
