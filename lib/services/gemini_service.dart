import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'secure_storage_service.dart';
part 'gemini_service.g.dart';

class GeminiAttempt {
  final String model;
  final String response;

  const GeminiAttempt({required this.model, required this.response});
}

class GeminiService {
  static const models = <String>[
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
  ];

  final SecureStorageService storage;

  GeminiService(this.storage);

  Future<GeminiAttempt> generateJson(
    String prompt, {
    void Function(String model, int attempt, int total)? onAttempt,
  }) async {
    final apiKey = await storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Gemini API key is not configured.');
    }

    Object? lastError;

    for (var index = 0; index < models.length; index++) {
      final modelName = models[index];
      onAttempt?.call(modelName, index + 1, models.length);
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim();

        if (text == null || text.isEmpty) {
          throw StateError('The model returned an empty response.');
        }

        // Invalid JSON is treated as a model failure and triggers fallback.
        jsonDecode(text);

        return GeminiAttempt(model: modelName, response: text);
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(
      'All configured Gemini models failed. Last error: $lastError',
    );
  }
}

@riverpod
GeminiService geminiService(Ref ref) {
  return GeminiService(ref.watch(secureStorageServiceProvider));
}
