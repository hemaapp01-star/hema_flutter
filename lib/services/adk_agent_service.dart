import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with the custom Hema Agent API
class AdkAgentService {
  static const String _baseUrl = 'https://hema-agent-service-103983913840.us-central1.run.app';

  /// Create/initialize a session for the user
  /// This ensures the session exists in the backend's memory service
  /// 
  /// [userId] - The user's Firebase UID
  /// [sessionId] - The session ID (typically same as userId)
  static Future<bool> createSession({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final url = '$_baseUrl/chat';
      debugPrint('🔧 Initializing Hema Agent session: $url');
      
      // Send an empty message to initialize the session
      // The backend will create the session if it doesn't exist
      final requestBody = <String, dynamic>{
        'user_id': userId,
        'session_id': sessionId,
        'message': '',  // Empty message for initialization
        'context': {},
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Session initialization timeout after 10 seconds');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Hema Agent session initialized: $sessionId');
        return true;
      } else {
        debugPrint('❌ Failed to initialize session: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error initializing Hema Agent session: $e');
      return false;
    }
  }

  /// Send a message to the Hema agent with context
  /// 
  /// [userId] - The user's Firebase UID
  /// [sessionId] - The session ID (typically same as userId)
  /// [message] - The user's message
  /// [context] - The blood request context to pass to the agent
  static Future<String> sendMessage({
    required String userId,
    required String sessionId,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    try {
      final url = '$_baseUrl/chat';
      debugPrint('🚀 Sending message to Hema Agent: $url');
      
      final requestBody = <String, dynamic>{
        'user_id': userId,
        'session_id': sessionId,
        'message': message,
        'context': context ?? {},
      };

      debugPrint('📦 Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⚠️ Hema Agent message timeout after 30 seconds');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Hema Agent response received: ${response.statusCode}');
        debugPrint('📦 Response body: ${response.body}');
        
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = decoded['reply'] as String?;
        
        if (reply != null && reply.isNotEmpty) {
          debugPrint('✅ Extracted reply: ${reply.substring(0, reply.length > 50 ? 50 : reply.length)}...');
          return reply;
        }
        
        debugPrint('⚠️ Hema Agent returned empty reply');
        return 'I apologize, but I received an empty response. Please try again.';
      } else {
        debugPrint('❌ Hema Agent API error: ${response.statusCode} - ${response.body}');
        return 'I apologize, but I\'m having trouble connecting right now. Please try again.';
      }
    } catch (e) {
      if (e.toString().contains('Failed to fetch') || e.toString().contains('XMLHttpRequest')) {
        debugPrint('⚠️ CORS Error: The Hema Agent API server needs to allow cross-origin requests. Error: $e');
      } else {
        debugPrint('❌ Error calling Hema Agent API: $e');
      }
      return 'I apologize, but I\'m having trouble connecting right now. Please try again.';
    }
  }
}
