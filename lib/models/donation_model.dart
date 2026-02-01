import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single blood donation record
class DonationModel {
  final String id;
  final String donorId;
  final String providerId;
  final String providerName;
  final String location;
  final String bloodType;
  final String component;
  final DateTime donationDate;
  final int unitsCollected;
  final String? notes;
  final DateTime createdAt;

  const DonationModel({
    required this.id,
    required this.donorId,
    required this.providerId,
    required this.providerName,
    required this.location,
    required this.bloodType,
    required this.component,
    required this.donationDate,
    required this.unitsCollected,
    this.notes,
    required this.createdAt,
  });

  /// Create DonationModel from Firestore document
  factory DonationModel.fromJson(Map<String, dynamic> json) => DonationModel(
    id: json['id'] as String,
    donorId: json['donorId'] as String,
    providerId: json['providerId'] as String,
    providerName: json['providerName'] as String,
    location: json['location'] as String,
    bloodType: json['bloodType'] as String,
    component: json['component'] as String,
    donationDate: (json['donationDate'] as Timestamp).toDate(),
    unitsCollected: json['unitsCollected'] as int? ?? 1,
    notes: json['notes'] as String?,
    createdAt: (json['createdAt'] as Timestamp).toDate(),
  );

  /// Convert DonationModel to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'id': id,
    'donorId': donorId,
    'providerId': providerId,
    'providerName': providerName,
    'location': location,
    'bloodType': bloodType,
    'component': component,
    'donationDate': Timestamp.fromDate(donationDate),
    'unitsCollected': unitsCollected,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// Copy with updated fields
  DonationModel copyWith({
    String? id,
    String? donorId,
    String? providerId,
    String? providerName,
    String? location,
    String? bloodType,
    String? component,
    DateTime? donationDate,
    int? unitsCollected,
    String? notes,
    DateTime? createdAt,
  }) => DonationModel(
    id: id ?? this.id,
    donorId: donorId ?? this.donorId,
    providerId: providerId ?? this.providerId,
    providerName: providerName ?? this.providerName,
    location: location ?? this.location,
    bloodType: bloodType ?? this.bloodType,
    component: component ?? this.component,
    donationDate: donationDate ?? this.donationDate,
    unitsCollected: unitsCollected ?? this.unitsCollected,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
}
