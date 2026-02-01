import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// Message role - from user, Hema agent, or blood request
enum MessageRole {
  user,
  hema,
  request;

  String toJson() => name;
  
  static MessageRole fromJson(String value) {
    return MessageRole.values.firstWhere((e) => e.name == value);
  }
}

/// Model for chat messages in the messages subcollection under donors
class MessageModel {
  final String id;
  final String content;
  final MessageRole? role;
  final String? roleString; // For provider roles like "provider-{id}"
  final DateTime date;

  const MessageModel({
    required this.id,
    required this.content,
    this.role,
    this.roleString,
    required this.date,
  });

  /// Create MessageModel from Firestore document
  factory MessageModel.fromJson(Map<String, dynamic> json, String id) {
    final roleValue = json['role'] as String;
    
    // Handle content that might be stored as a Map (JSON object) instead of a String
    String contentStr;
    if (json['content'] is Map) {
      try {
        contentStr = jsonEncode(json['content'], toEncodable: (nonEncodable) {
          if (nonEncodable is GeoPoint) {
            return {
              'latitude': nonEncodable.latitude,
              'longitude': nonEncodable.longitude,
            };
          }
          if (nonEncodable is Timestamp) {
            return nonEncodable.toDate().toIso8601String();
          }
          return nonEncodable.toString();
        });
      } catch (e) {
        contentStr = json['content'].toString();
      }
    } else {
      contentStr = json['content'].toString();
    }

    // Get date from various possible field names
    final dateField = json['date'] ?? json['timeStamp'] ?? json['timestamp'];
    final date = dateField is Timestamp 
        ? dateField.toDate() 
        : DateTime.now(); // Fallback to now if missing/invalid

    // Check if it's a provider role (starts with "provider-")
    if (roleValue.startsWith('provider-')) {
      return MessageModel(
        id: id,
        content: contentStr,
        roleString: roleValue,
        date: date,
      );
    }
    
    // Otherwise, it's a standard enum role
    return MessageModel(
      id: id,
      content: contentStr,
      role: MessageRole.fromJson(roleValue),
      date: date,
    );
  }

  /// Convert MessageModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': roleString ?? role!.toJson(),
      'date': Timestamp.fromDate(date),
    };
  }

  /// Copy with updated fields
  MessageModel copyWith({
    String? id,
    String? content,
    MessageRole? role,
    String? roleString,
    DateTime? date,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      roleString: roleString ?? this.roleString,
      date: date ?? this.date,
    );
  }
  
  /// Check if this message is from a provider
  bool get isProvider => roleString != null && roleString!.startsWith('provider-');
  
  /// Get provider ID from role string (e.g., "provider-abc123" -> "abc123")
  String? get providerId {
    if (isProvider) {
      return roleString!.substring(9); // Remove "provider-" prefix
    }
    return null;
  }
}
