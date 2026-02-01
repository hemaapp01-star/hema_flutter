import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Model for chat messages between provider and donor
class ChatMessage {
  final String id;
  final String content;
  final String role; // Format: "provider-{providerId}"
  final DateTime date;
  final String? providerId;
  final String? requestId;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.date,
    this.providerId,
    this.requestId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      content: json['content'] as String,
      role: json['role'] as String,
      date: (json['date'] as Timestamp).toDate(),
      providerId: json['providerId'] as String?,
      requestId: json['requestId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role,
      'date': Timestamp.fromDate(date),
      'providerId': providerId,
      'requestId': requestId,
    };
  }
}

/// Service for handling provider-donor chat messages
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensure the session document path exists in Firestore
  /// Path: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages
  Future<void> ensureSessionExists({
    required String donorId,
    required String requestId,
    required String providerId,
  }) async {
    try {
      // Create a metadata document to ensure the path exists
      final metadataDoc = _firestore
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('conversations')
          .doc(requestId)
          .collection('donors')
          .doc(donorId)
          .collection('messages')
          .doc('_metadata');

      final snapshot = await metadataDoc.get();
      
      if (!snapshot.exists) {
        await metadataDoc.set({
          'createdAt': Timestamp.now(),
          'donorId': donorId,
          'requestId': requestId,
        });
        debugPrint('Session path created: healthcare_providers/$providerId/conversations/$requestId/donors/$donorId/messages');
      }
    } catch (e) {
      debugPrint('Error ensuring session exists: $e');
      rethrow;
    }
  }

  /// Send a message from provider to donor
  /// Messages are stored in:
  /// 1. users/{donorId}/messages/{messageId}
  /// 2. healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages/{messageId}
  Future<void> sendMessage({
    required String donorId,
    required String requestId,
    required String providerId,
    required String content,
  }) async {
    try {
      final now = DateTime.now();
      final role = 'provider-$providerId';

      final messageData = {
        'content': content,
        'role': role,
        'date': Timestamp.fromDate(now),
        'providerId': providerId,
        'requestId': requestId,
      };

      // 1. Add message to donor's messages subcollection
      final donorMessageRef = await _firestore
          .collection('users')
          .doc(donorId)
          .collection('messages')
          .add(messageData);

      debugPrint('Message added to donor messages: ${donorMessageRef.id}');

      // 2. Add message to provider's conversation
      // Path: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages/{messageId}
      final conversationPath = 'healthcare_providers/$providerId/conversations/$requestId/donors/$donorId/messages';
      await _firestore
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('conversations')
          .doc(requestId)
          .collection('donors')
          .doc(donorId)
          .collection('messages')
          .doc(donorMessageRef.id)
          .set(messageData);

      debugPrint('Message saved to: $conversationPath/${donorMessageRef.id}');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get all messages for a specific provider-donor conversation
  /// Reads from: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages
  Future<List<ChatMessage>> getMessages({
    required String donorId,
    required String requestId,
    required String providerId,
    Source source = Source.serverAndCache,
  }) async {
    try {
      final conversationPath = 'healthcare_providers/$providerId/conversations/$requestId/donors/$donorId/messages';
      debugPrint('Reading messages from: $conversationPath (source: $source)');
      
      final snapshot = await _firestore
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('conversations')
          .doc(requestId)
          .collection('donors')
          .doc(donorId)
          .collection('messages')
          .orderBy('date', descending: false)
          .get(GetOptions(source: source));

      // Filter out the metadata document
      return snapshot.docs
          .where((doc) => doc.id != '_metadata')
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Stream messages for real-time updates
  /// Path: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages
  Stream<List<ChatMessage>> streamMessages({
    required String donorId,
    required String requestId,
    required String providerId,
  }) {
    return _firestore
        .collection('healthcare_providers')
        .doc(providerId)
        .collection('conversations')
        .doc(requestId)
        .collection('donors')
        .doc(donorId)
        .collection('messages')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      // Filter out the metadata document
      return snapshot.docs
          .where((doc) => doc.id != '_metadata')
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList();
    });
  }
}
