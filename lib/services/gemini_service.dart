import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini AI service for Hema chat functionality
class GeminiService {
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static GenerativeModel? _model;

  /// Initialize the Gemini model
  static GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
    return _model!;
  }

  /// Send a chat message and get a response from Hema
  static Future<String> sendChatMessage({
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
  }) async {
    try {
      // Build conversation history for Gemini
      final conversationHistory = <Content>[];
      
      for (var msg in messages) {
        if (msg['role'] == 'system') continue;
        
        final messageRole = msg['role'] == 'user' ? 'user' : 'model';
        final messageContent = msg['content'] as String;
        
        conversationHistory.add(Content(messageRole, [TextPart(messageContent)]));
      }

      // Create chat session with history (excluding the last message)
      final chat = model.startChat(
        history: conversationHistory.isEmpty
            ? []
            : conversationHistory.sublist(0, conversationHistory.length - 1),
      );

      // Get the last user message
      final lastMessage = messages.last['content'] as String;

      // Include system prompt if provided
      final prompt = systemPrompt != null
          ? '$systemPrompt\n\nUser: $lastMessage'
          : lastMessage;

      // Send message and get response
      final response = await chat.sendMessage(Content.text(prompt));
      return response.text ?? 'Sorry, I could not generate a response.';
    } catch (e) {
      debugPrint('Error sending chat message to Gemini: $e');
      rethrow;
    }
  }
}
