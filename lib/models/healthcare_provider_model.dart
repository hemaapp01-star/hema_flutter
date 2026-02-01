import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';

/// Healthcare Provider model representing hospitals, clinics, blood banks, etc.
class HealthcareProviderModel {
  final String id; // Document ID (auto-generated)
  final String organizationName;
  final ProviderType providerType;
  
  // Location information
  final String country;
  final String countryCode; // 2-letter country code (e.g., 'NG')
  final String city;
  final String address; // Full address
  final double latitude;
  final double longitude;
  final Map<String, dynamic> geo; // Geohash data for location queries (from geoflutterfire_plus)
  final String? placeId; // Google Places ID for the facility
  
  // Contact information
  final String? phoneNumber;
  final String? email;
  final String? website;
  
  // Verification and status
  final String? licenseFileUrl;
  final bool isVerified; // Whether the provider has been verified by admin
  final bool isActive; // Whether the provider is currently active
  
  // Operating hours (optional)
  final Map<String, String>? operatingHours; // e.g., {'monday': '8:00-17:00', 'tuesday': '8:00-17:00'}
  
  // Services offered (optional)
  final List<String>? servicesOffered; // e.g., ['Blood Donation', 'Blood Testing', 'Emergency Services']
  
  // Associated doctors/staff (references to user documents)
  final List<String> associatedDoctors; // List of user IDs (doctors affiliated with this provider)
  
  // Statistics
  final int? totalDoctors; // Total number of doctors affiliated
  final int? totalBloodDonationsReceived; // Total blood donations received at this facility
  final int activeRequests; // Number of active blood requests
  final int bloodInventory; // Total blood units in inventory
  final int donorsMatched; // Number of donors matched to requests
  final int donationsThisMonth; // Number of donations received this month
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthcareProviderModel({
    required this.id,
    required this.organizationName,
    required this.providerType,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.geo,
    this.placeId,
    this.phoneNumber,
    this.email,
    this.website,
    this.licenseFileUrl,
    this.isVerified = false,
    this.isActive = true,
    this.operatingHours,
    this.servicesOffered,
    this.associatedDoctors = const [],
    this.totalDoctors,
    this.totalBloodDonationsReceived,
    this.activeRequests = 0,
    this.bloodInventory = 0,
    this.donorsMatched = 0,
    this.donationsThisMonth = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a HealthcareProviderModel from JSON/Firestore data
  factory HealthcareProviderModel.fromJson(Map<String, dynamic> json) {
    return HealthcareProviderModel(
      id: json['id'] as String,
      organizationName: json['organizationName'] as String,
      providerType: ProviderType.fromJson(json['providerType'] as String),
      country: json['country'] as String,
      countryCode: json['countryCode'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geo: Map<String, dynamic>.from(json['geo'] as Map),
      placeId: json['placeId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      licenseFileUrl: json['licenseFileUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      operatingHours: json['operatingHours'] != null
          ? Map<String, String>.from(json['operatingHours'] as Map)
          : null,
      servicesOffered: json['servicesOffered'] != null
          ? List<String>.from(json['servicesOffered'] as List)
          : null,
      associatedDoctors: json['associatedDoctors'] != null
          ? List<String>.from(json['associatedDoctors'] as List)
          : [],
      totalDoctors: json['totalDoctors'] as int?,
      totalBloodDonationsReceived: json['totalBloodDonationsReceived'] as int?,
      activeRequests: json['activeRequests'] as int? ?? 0,
      bloodInventory: json['bloodInventory'] as int? ?? 0,
      donorsMatched: json['donorsMatched'] as int? ?? 0,
      donationsThisMonth: json['donationsThisMonth'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert HealthcareProviderModel to JSON/Firestore data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationName': organizationName,
      'providerType': providerType.toJson(),
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geo': geo,
      'placeId': placeId,
      'phoneNumber': phoneNumber,
      'email': email,
      'website': website,
      'licenseFileUrl': licenseFileUrl,
      'isVerified': isVerified,
      'isActive': isActive,
      'operatingHours': operatingHours,
      'servicesOffered': servicesOffered,
      'associatedDoctors': associatedDoctors,
      'totalDoctors': totalDoctors,
      'totalBloodDonationsReceived': totalBloodDonationsReceived,
      'activeRequests': activeRequests,
      'bloodInventory': bloodInventory,
      'donorsMatched': donorsMatched,
      'donationsThisMonth': donationsThisMonth,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  HealthcareProviderModel copyWith({
    String? id,
    String? organizationName,
    ProviderType? providerType,
    String? country,
    String? countryCode,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? geo,
    String? placeId,
    String? phoneNumber,
    String? email,
    String? website,
    String? licenseFileUrl,
    bool? isVerified,
    bool? isActive,
    Map<String, String>? operatingHours,
    List<String>? servicesOffered,
    List<String>? associatedDoctors,
    int? totalDoctors,
    int? totalBloodDonationsReceived,
    int? activeRequests,
    int? bloodInventory,
    int? donorsMatched,
    int? donationsThisMonth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthcareProviderModel(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      providerType: providerType ?? this.providerType,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geo: geo ?? this.geo,
      placeId: placeId ?? this.placeId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      website: website ?? this.website,
      licenseFileUrl: licenseFileUrl ?? this.licenseFileUrl,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      operatingHours: operatingHours ?? this.operatingHours,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      associatedDoctors: associatedDoctors ?? this.associatedDoctors,
      totalDoctors: totalDoctors ?? this.totalDoctors,
      totalBloodDonationsReceived: totalBloodDonationsReceived ?? this.totalBloodDonationsReceived,
      activeRequests: activeRequests ?? this.activeRequests,
      bloodInventory: bloodInventory ?? this.bloodInventory,
      donorsMatched: donorsMatched ?? this.donorsMatched,
      donationsThisMonth: donationsThisMonth ?? this.donationsThisMonth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted location string
  String get fullLocation => '$city, $country';

  /// Get formatted address with city and country
  String get fullAddress => '$address, $city, $country';

  /// Check if provider has been verified
  bool get isVerifiedProvider => isVerified && isActive;

  /// Get number of associated doctors
  int get doctorsCount => associatedDoctors.length;
}
