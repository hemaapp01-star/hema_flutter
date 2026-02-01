import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for user type
enum UserType {
  donor,
  provider;

  String toJson() => name;
  
  static UserType fromJson(String value) {
    return UserType.values.firstWhere((e) => e.name == value);
  }
}

/// Enum for biological sex
enum BiologicalSex {
  male,
  female;

  String toJson() => name;
  
  static BiologicalSex fromJson(String value) {
    return BiologicalSex.values.firstWhere((e) => e.name == value);
  }
}

/// Enum for blood type
enum BloodType {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  oPositive('O+'),
  oNegative('O-'),
  abPositive('AB+'),
  abNegative('AB-'),
  unknown("Unknown");

  final String displayName;
  const BloodType(this.displayName);

  String toJson() => displayName;
  
  static BloodType fromJson(String value) {
    // Check for display name match first (new format e.g., 'A+')
    try {
      return BloodType.values.firstWhere((e) => e.displayName == value);
    } catch (_) {}

    // Fallback for legacy enum names (e.g., 'aPositive')
    try {
      return BloodType.values.firstWhere((e) => e.name == value);
    } catch (_) {}

    // Handle onboarding "I don't know" specifically if distinct from "Unknown"
    if (value == "I don't know") return BloodType.unknown;

    return BloodType.unknown;
  }
}

/// Enum for healthcare provider type
enum ProviderType {
  hospital,
  clinic,
  bloodBank,
  emergencyServices;

  String toJson() => name;
  
  static ProviderType fromJson(String value) {
    return ProviderType.values.firstWhere((e) => e.name == value);
  }

  String get displayName {
    switch (this) {
      case ProviderType.hospital:
        return 'Hospital';
      case ProviderType.clinic:
        return 'Clinic';
      case ProviderType.bloodBank:
        return 'Blood Bank';
      case ProviderType.emergencyServices:
        return 'Emergency Services';
    }
  }
}

/// Unified user model for both donors and healthcare providers
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String surname;
  final String? phoneNumber;
  final UserType? userType;
  
  // Common fields
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Donor-specific fields - Basic Info
  final DateTime? dateOfBirth;
  final BiologicalSex? biologicalSex;
  final int? weight; // in lbs
  final BloodType? bloodType;
  final String? country; // Country name
  final String? countryCode; // 2-letter country code (e.g., 'US')
  final String? city; // City name
  final String? daytimeAddress; // Neighborhood for daytime
  final String? nighttimeAddress; // Neighborhood for nighttime
  
  // Donor-specific fields - Availability & Status
  final bool? isAvailable; // Whether donor is currently available for immediate requests
  final bool? activeRequest; // Whether donor is in an active matching/donation process
  final DateTime? lastDonationDate; // Date of last blood donation
  final DateTime? nextEligibleDate; // Date when donor is eligible to donate again (56 days after last donation)
  
  // Donor-specific fields - Impact & Gamification
  final int? totalDonations; // Total number of successful donations
  final int? livesSaved; // Estimated lives saved (typically 3 lives per donation)
  final List<String>? badges; // List of earned badges (e.g., 'bronze_donor', 'silver_donor', 'gold_donor')
  final int? heroLevel; // Gamification level based on donations
  
  // Provider-specific fields
  final String? providerId; // Reference to healthcare_providers collection (for doctors affiliated with a provider)
  final String? organizationName;
  final ProviderType? providerType;
  final String? address; // Provider organization address
  final String? licenseFileUrl;
  final bool? isVerified; // Whether the provider's license has been verified
  final bool? isAccountActive; // Whether the provider account is active
  
  // Onboarding status
  final bool onboarded; // Whether the user has completed onboarding

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.surname,
    this.phoneNumber,
    this.userType,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.biologicalSex,
    this.weight,
    this.bloodType,
    this.country,
    this.countryCode,
    this.city,
    this.daytimeAddress,
    this.nighttimeAddress,
    this.isAvailable,
    this.activeRequest,
    this.lastDonationDate,
    this.nextEligibleDate,
    this.totalDonations,
    this.livesSaved,
    this.badges,
    this.heroLevel,
    this.providerId,
    this.organizationName,
    this.providerType,
    this.address,
    this.licenseFileUrl,
    this.isVerified,
    this.isAccountActive,
    this.onboarded = false,
  });

  /// Create a UserModel from JSON/Firestore data
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      surname: json['surname'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      userType: json['userType'] != null ? UserType.fromJson(json['userType'] as String) : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      dateOfBirth: json['dateOfBirth'] != null
          ? (json['dateOfBirth'] as Timestamp).toDate()
          : null,
      biologicalSex: json['biologicalSex'] != null
          ? BiologicalSex.fromJson(json['biologicalSex'] as String)
          : null,
      weight: json['weight'] as int?,
      bloodType: json['bloodType'] != null
          ? BloodType.fromJson(json['bloodType'] as String)
          : null,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      city: json['city'] as String?,
      daytimeAddress: json['daytimeAddress'] as String?,
      nighttimeAddress: json['nighttimeAddress'] as String?,
      isAvailable: json['isAvailable'] as bool?,
      activeRequest: json['activeRequest'] as bool?,
      lastDonationDate: json['lastDonationDate'] != null
          ? (json['lastDonationDate'] as Timestamp).toDate()
          : null,
      nextEligibleDate: json['nextEligibleDate'] != null
          ? (json['nextEligibleDate'] as Timestamp).toDate()
          : null,
      totalDonations: json['totalDonations'] as int?,
      livesSaved: json['livesSaved'] as int?,
      badges: json['badges'] != null
          ? List<String>.from(json['badges'] as List)
          : null,
      heroLevel: json['heroLevel'] as int?,
      providerId: json['providerId'] as String?,
      organizationName: json['organizationName'] as String?,
      providerType: json['providerType'] != null
          ? ProviderType.fromJson(json['providerType'] as String)
          : null,
      address: json['address'] as String?,
      licenseFileUrl: json['licenseFileUrl'] as String?,
      isVerified: json['isVerified'] as bool?,
      isAccountActive: json['isAccountActive'] as bool?,
      onboarded: json['onboarded'] as bool? ?? false,
    );
  }

  /// Convert UserModel to JSON/Firestore data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'surname': surname,
      'phoneNumber': phoneNumber,
      'userType': userType?.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'biologicalSex': biologicalSex?.toJson(),
      'weight': weight,
      'bloodType': bloodType?.toJson(),
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'daytimeAddress': daytimeAddress,
      'nighttimeAddress': nighttimeAddress,
      'isAvailable': isAvailable,
      'activeRequest': activeRequest,
      'lastDonationDate': lastDonationDate != null ? Timestamp.fromDate(lastDonationDate!) : null,
      'nextEligibleDate': nextEligibleDate != null ? Timestamp.fromDate(nextEligibleDate!) : null,
      'totalDonations': totalDonations,
      'livesSaved': livesSaved,
      'badges': badges,
      'heroLevel': heroLevel,
      'providerId': providerId,
      'organizationName': organizationName,
      'providerType': providerType?.toJson(),
      'address': address,
      'licenseFileUrl': licenseFileUrl,
      'isVerified': isVerified,
      'isAccountActive': isAccountActive,
      'onboarded': onboarded,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? surname,
    String? phoneNumber,
    UserType? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateOfBirth,
    BiologicalSex? biologicalSex,
    int? weight,
    BloodType? bloodType,
    String? country,
    String? countryCode,
    String? city,
    String? daytimeAddress,
    String? nighttimeAddress,
    bool? isAvailable,
    bool? activeRequest,
    DateTime? lastDonationDate,
    DateTime? nextEligibleDate,
    int? totalDonations,
    int? livesSaved,
    List<String>? badges,
    int? heroLevel,
    String? providerId,
    String? organizationName,
    ProviderType? providerType,
    String? address,
    String? licenseFileUrl,
    bool? isVerified,
    bool? isAccountActive,
    bool? onboarded,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      surname: surname ?? this.surname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      weight: weight ?? this.weight,
      bloodType: bloodType ?? this.bloodType,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      daytimeAddress: daytimeAddress ?? this.daytimeAddress,
      nighttimeAddress: nighttimeAddress ?? this.nighttimeAddress,
      isAvailable: isAvailable ?? this.isAvailable,
      activeRequest: activeRequest ?? this.activeRequest,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      nextEligibleDate: nextEligibleDate ?? this.nextEligibleDate,
      totalDonations: totalDonations ?? this.totalDonations,
      livesSaved: livesSaved ?? this.livesSaved,
      badges: badges ?? this.badges,
      heroLevel: heroLevel ?? this.heroLevel,
      providerId: providerId ?? this.providerId,
      organizationName: organizationName ?? this.organizationName,
      providerType: providerType ?? this.providerType,
      address: address ?? this.address,
      licenseFileUrl: licenseFileUrl ?? this.licenseFileUrl,
      isVerified: isVerified ?? this.isVerified,
      isAccountActive: isAccountActive ?? this.isAccountActive,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  /// Get full name by combining firstName and surname
  String get fullName => '$firstName $surname'.trim();

  /// Check if user is a donor
  bool get isDonor => userType == UserType.donor;

  /// Check if user is a provider
  bool get isProvider => userType == UserType.provider;

  /// Calculate age from date of birth (for donors)
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  /// Check if donor is eligible to donate (18-65 years, weight >= 110 lbs)
  bool get isEligibleToDonate {
    if (!isDonor) return false;
    final calculatedAge = age;
    if (calculatedAge == null || calculatedAge < 18 || calculatedAge > 65) {
      return false;
    }
    if (weight == null || weight! < 110) return false;
    return true;
  }

  /// Calculate days remaining until next eligible donation (56 days from last donation)
  int? get daysUntilEligible {
    if (!isDonor || lastDonationDate == null) return null;
    final now = DateTime.now();
    final eligibleDate = nextEligibleDate ?? lastDonationDate!.add(const Duration(days: 56));
    final difference = eligibleDate.difference(now).inDays;
    return difference > 0 ? difference : 0;
  }

  /// Check if donor is currently eligible based on time since last donation
  bool get isCurrentlyEligible {
    if (!isDonor) return false;
    if (!isEligibleToDonate) return false; // Basic eligibility check
    if (lastDonationDate == null) return true; // Never donated before
    final days = daysUntilEligible;
    return days != null && days <= 0;
  }

  /// Calculate donation progress (0.0 to 1.0) for UI progress indicators
  double get donationProgress {
    if (!isDonor || lastDonationDate == null) return 1.0;
    final totalDays = 56;
    final daysRemaining = daysUntilEligible ?? 0;
    final daysPassed = totalDays - daysRemaining;
    return (daysPassed / totalDays).clamp(0.0, 1.0);
  }

  /// Get hero level based on total donations
  String get heroLevelName {
    if (!isDonor || totalDonations == null) return 'New Hero';
    if (totalDonations! >= 50) return 'Diamond Hero';
    if (totalDonations! >= 25) return 'Platinum Hero';
    if (totalDonations! >= 10) return 'Gold Hero';
    if (totalDonations! >= 5) return 'Silver Hero';
    if (totalDonations! >= 1) return 'Bronze Hero';
    return 'New Hero';
  }
}
