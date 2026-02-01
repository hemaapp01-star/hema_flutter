import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';

/// Provider verification status enum
enum VerificationStatus {
  pending,
  approved,
  rejected;

  String toJson() => name;

  static VerificationStatus fromJson(String json) =>
      VerificationStatus.values.firstWhere((e) => e.name == json);
}

/// Model for provider verification documents
class ProviderVerificationModel {
  final String id; // Document ID
  final String userId; // UID of the user who uploaded the document
  final String providerId; // Reference to the healthcare provider
  final String organizationName; // Name of the healthcare organization
  final ProviderType providerType; // Type of provider
  final String licenseStoragePath; // Storage path in Firebase Storage
  final String licenseDownloadUrl; // Download URL for the license
  final VerificationStatus status; // Verification status
  final String? reviewNotes; // Admin notes during review
  final String? reviewedBy; // User ID of admin who reviewed
  final DateTime? reviewedAt; // Timestamp of review
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProviderVerificationModel({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.organizationName,
    required this.providerType,
    required this.licenseStoragePath,
    required this.licenseDownloadUrl,
    this.status = VerificationStatus.pending,
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory ProviderVerificationModel.fromJson(Map<String, dynamic> json) {
    return ProviderVerificationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      providerId: json['providerId'] as String,
      organizationName: json['organizationName'] as String,
      providerType: ProviderType.fromJson(json['providerType'] as String),
      licenseStoragePath: json['licenseStoragePath'] as String,
      licenseDownloadUrl: json['licenseDownloadUrl'] as String,
      status: VerificationStatus.fromJson(json['status'] as String),
      reviewNotes: json['reviewNotes'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? (json['reviewedAt'] as Timestamp).toDate()
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'providerId': providerId,
      'organizationName': organizationName,
      'providerType': providerType.toJson(),
      'licenseStoragePath': licenseStoragePath,
      'licenseDownloadUrl': licenseDownloadUrl,
      'status': status.toJson(),
      'reviewNotes': reviewNotes,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  ProviderVerificationModel copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? organizationName,
    ProviderType? providerType,
    String? licenseStoragePath,
    String? licenseDownloadUrl,
    VerificationStatus? status,
    String? reviewNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProviderVerificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      organizationName: organizationName ?? this.organizationName,
      providerType: providerType ?? this.providerType,
      licenseStoragePath: licenseStoragePath ?? this.licenseStoragePath,
      licenseDownloadUrl: licenseDownloadUrl ?? this.licenseDownloadUrl,
      status: status ?? this.status,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if verification is pending
  bool get isPending => status == VerificationStatus.pending;

  /// Check if verification is approved
  bool get isApproved => status == VerificationStatus.approved;

  /// Check if verification is rejected
  bool get isRejected => status == VerificationStatus.rejected;
}
