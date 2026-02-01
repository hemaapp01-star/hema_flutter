import 'package:cloud_firestore/cloud_firestore.dart';

/// Blood Request model representing a request for blood donation
class BloodRequestModel {
  final String id;
  final String providerId; // Healthcare provider making the request
  final String requestedBy; // User ID of the person creating the request
  final String title; // Brief title of the request
  final String notes; // Additional details or notes
  final String bloodGroup; // Blood group needed (A+, A-, B+, B-, AB+, AB-, O+, O-)
  final BloodComponent component; // Type of blood component required
  final UrgencyLevel urgency; // How urgent is the request
  final int quantity; // Number of units needed
  final RequestStatus status; // Current status of the request
  final DateTime? requiredBy; // When the blood is needed by
  final String? patientName; // Optional patient name
  final String? contactPhone; // Contact phone for the request
  final List<String> matchedDonors; // List of donor IDs matched to this request
  final List<String> acceptedDonors; // List of donor IDs who accepted but not yet matched
  final DateTime createdAt;
  final DateTime updatedAt;

  const BloodRequestModel({
    required this.id,
    required this.providerId,
    required this.requestedBy,
    required this.title,
    required this.notes,
    required this.bloodGroup,
    required this.component,
    required this.urgency,
    required this.quantity,
    required this.status,
    this.requiredBy,
    this.patientName,
    this.contactPhone,
    this.matchedDonors = const [],
    this.acceptedDonors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a BloodRequestModel from JSON/Firestore data
  factory BloodRequestModel.fromJson(Map<String, dynamic> json) {
    // Handle bloodGroup which could be either a String or List<String>
    String bloodGroupValue;
    final bloodGroupData = json['bloodGroup'];
    if (bloodGroupData is List) {
      // If it's a list (compatible blood groups), use the first one or fallback
      bloodGroupValue = (bloodGroupData.isNotEmpty) 
          ? bloodGroupData[0] as String 
          : json['patientBloodGroup'] as String? ?? 'O+';
    } else {
      bloodGroupValue = bloodGroupData as String;
    }

    return BloodRequestModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      requestedBy: json['requestedBy'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      bloodGroup: bloodGroupValue,
      component: BloodComponent.fromJson(json['component'] as String),
      urgency: UrgencyLevel.fromJson(json['urgency'] as String),
      quantity: json['quantity'] as int? ?? 1,
      status: RequestStatus.fromJson(json['status'] as String),
      requiredBy: json['requiredBy'] != null
          ? (json['requiredBy'] as Timestamp).toDate()
          : null,
      patientName: json['patientName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      matchedDonors: json['matchedDonors'] != null
          ? List<String>.from(json['matchedDonors'] as List)
          : [],
      acceptedDonors: json['acceptedDonors'] != null
          ? List<String>.from(json['acceptedDonors'] as List)
          : [],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert BloodRequestModel to JSON/Firestore data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'requestedBy': requestedBy,
      'title': title,
      'notes': notes,
      'bloodGroup': bloodGroup,
      'component': component.toJson(),
      'urgency': urgency.toJson(),
      'quantity': quantity,
      'status': status.toJson(),
      'requiredBy': requiredBy != null ? Timestamp.fromDate(requiredBy!) : null,
      'patientName': patientName,
      'contactPhone': contactPhone,
      'matchedDonors': matchedDonors,
      'acceptedDonors': acceptedDonors,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  BloodRequestModel copyWith({
    String? id,
    String? providerId,
    String? requestedBy,
    String? title,
    String? notes,
    String? bloodGroup,
    BloodComponent? component,
    UrgencyLevel? urgency,
    int? quantity,
    RequestStatus? status,
    DateTime? requiredBy,
    String? patientName,
    String? contactPhone,
    List<String>? matchedDonors,
    List<String>? acceptedDonors,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BloodRequestModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      requestedBy: requestedBy ?? this.requestedBy,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      component: component ?? this.component,
      urgency: urgency ?? this.urgency,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      requiredBy: requiredBy ?? this.requiredBy,
      patientName: patientName ?? this.patientName,
      contactPhone: contactPhone ?? this.contactPhone,
      matchedDonors: matchedDonors ?? this.matchedDonors,
      acceptedDonors: acceptedDonors ?? this.acceptedDonors,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get urgency color
  String get urgencyColor {
    switch (urgency) {
      case UrgencyLevel.critical:
        return '#D32F2F';
      case UrgencyLevel.high:
        return '#F57C00';
      case UrgencyLevel.medium:
        return '#FBC02D';
      case UrgencyLevel.low:
        return '#388E3C';
    }
  }
}

/// Urgency level for blood requests
enum UrgencyLevel {
  critical,
  high,
  medium,
  low;

  String toJson() => name;

  static UrgencyLevel fromJson(String json) {
    return UrgencyLevel.values.firstWhere((e) => e.name == json);
  }

  String get displayName {
    switch (this) {
      case UrgencyLevel.critical:
        return 'Critical';
      case UrgencyLevel.high:
        return 'High';
      case UrgencyLevel.medium:
        return 'Medium';
      case UrgencyLevel.low:
        return 'Low';
    }
  }
}

/// Blood component type required
enum BloodComponent {
  wholeBlood,
  redBloodCells,
  platelets,
  plasma,
  cryoprecipitate;

  String toJson() => name;

  static BloodComponent fromJson(String json) {
    return BloodComponent.values.firstWhere((e) => e.name == json);
  }

  String get displayName {
    switch (this) {
      case BloodComponent.wholeBlood:
        return 'Whole Blood';
      case BloodComponent.redBloodCells:
        return 'Red Blood Cells';
      case BloodComponent.platelets:
        return 'Platelets';
      case BloodComponent.plasma:
        return 'Plasma';
      case BloodComponent.cryoprecipitate:
        return 'Cryoprecipitate';
    }
  }
}

/// Status of blood request
enum RequestStatus {
  open,
  matched,
  fulfilled,
  cancelled;

  String toJson() => name;

  static RequestStatus fromJson(String json) {
    return RequestStatus.values.firstWhere((e) => e.name == json);
  }

  String get displayName {
    switch (this) {
      case RequestStatus.open:
        return 'Open';
      case RequestStatus.matched:
        return 'Matched';
      case RequestStatus.fulfilled:
        return 'Fulfilled';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }
}
