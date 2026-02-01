import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for donor documents in the 'donors' collection
/// This is specifically structured for geospatial queries with geoflutterfire_plus
class DonorModel {
  final String uid;
  final String name;
  final String bloodGroup;
  
  // Geospatial data for daytime location
  final Map<String, dynamic> geoDaytime;
  
  // Geospatial data for nighttime location
  final Map<String, dynamic> geoNighttime;
  
  // Location metadata
  final String? country;
  final String? countryCode;
  final String? city;
  final String? daytimeAddress;
  final String? nighttimeAddress;
  
  // Availability
  final bool isAvailable;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime lastLocationUpdate;

  const DonorModel({
    required this.uid,
    required this.name,
    required this.bloodGroup,
    required this.geoDaytime,
    required this.geoNighttime,
    this.country,
    this.countryCode,
    this.city,
    this.daytimeAddress,
    this.nighttimeAddress,
    this.isAvailable = false,
    required this.createdAt,
    required this.lastLocationUpdate,
  });

  /// Create DonorModel from Firestore document
  factory DonorModel.fromJson(Map<String, dynamic> json) {
    return DonorModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      bloodGroup: json['bloodGroup'] as String,
      geoDaytime: json['geoDaytime'] as Map<String, dynamic>,
      geoNighttime: json['geoNighttime'] as Map<String, dynamic>,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      city: json['city'] as String?,
      daytimeAddress: json['daytimeAddress'] as String?,
      nighttimeAddress: json['nighttimeAddress'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLocationUpdate: (json['lastLocationUpdate'] as Timestamp).toDate(),
    );
  }

  /// Convert DonorModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'bloodGroup': bloodGroup,
      'geoDaytime': geoDaytime,
      'geoNighttime': geoNighttime,
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'daytimeAddress': daytimeAddress,
      'nighttimeAddress': nighttimeAddress,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate),
    };
  }

  /// Copy with updated fields
  DonorModel copyWith({
    String? uid,
    String? name,
    String? bloodGroup,
    Map<String, dynamic>? geoDaytime,
    Map<String, dynamic>? geoNighttime,
    String? country,
    String? countryCode,
    String? city,
    String? daytimeAddress,
    String? nighttimeAddress,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? lastLocationUpdate,
  }) {
    return DonorModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      geoDaytime: geoDaytime ?? this.geoDaytime,
      geoNighttime: geoNighttime ?? this.geoNighttime,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      daytimeAddress: daytimeAddress ?? this.daytimeAddress,
      nighttimeAddress: nighttimeAddress ?? this.nighttimeAddress,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }

  /// Extract GeoPoint from geoDaytime
  GeoPoint get daytimeGeoPoint => geoDaytime['geopoint'] as GeoPoint;

  /// Extract GeoPoint from geoNighttime
  GeoPoint get nighttimeGeoPoint => geoNighttime['geopoint'] as GeoPoint;

  /// Extract geohash from geoDaytime
  String get daytimeGeohash => geoDaytime['geohash'] as String;

  /// Extract geohash from geoNighttime
  String get nighttimeGeohash => geoNighttime['geohash'] as String;
}
