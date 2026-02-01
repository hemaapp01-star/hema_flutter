import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hema/models/healthcare_provider_model.dart';
import 'package:hema/models/user_model.dart';

/// Service for managing healthcare providers in Firestore
class HealthcareProviderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference for healthcare providers
  CollectionReference<Map<String, dynamic>> get _providersCollection =>
      _firestore.collection('healthcare_providers');

  /// Collection reference for users
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Create a new healthcare provider
  /// 
  /// This method should be called at the end of provider onboarding.
  /// It creates the provider document with geohash data for location queries.
  Future<String> createProvider({
    required String organizationName,
    required ProviderType providerType,
    required String country,
    required String countryCode,
    required String city,
    required String address,
    required double latitude,
    required double longitude,
    String? placeId,
    String? phoneNumber,
    String? email,
    String? website,
    String? licenseFileUrl,
    Map<String, String>? operatingHours,
    List<String>? servicesOffered,
    String? createdByUserId, // User ID of the person who created this provider (will be added to associatedDoctors)
  }) async {
    try {
      // Create GeoFirePoint for location
      final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));

      final now = DateTime.now();
      final docRef = _providersCollection.doc(); // Auto-generate ID

      // Create provider data
      final provider = HealthcareProviderModel(
        id: docRef.id,
        organizationName: organizationName,
        providerType: providerType,
        country: country,
        countryCode: countryCode,
        city: city,
        address: address,
        latitude: latitude,
        longitude: longitude,
        geo: geoFirePoint.data,
        placeId: placeId,
        phoneNumber: phoneNumber,
        email: email,
        website: website,
        licenseFileUrl: licenseFileUrl,
        isVerified: false, // Needs admin verification
        isActive: false, // Inactive until verified
        operatingHours: operatingHours,
        servicesOffered: servicesOffered,
        associatedDoctors: createdByUserId != null ? [createdByUserId] : [],
        totalDoctors: createdByUserId != null ? 1 : 0,
        totalBloodDonationsReceived: 0,
        createdAt: now,
        updatedAt: now,
      );

      // Write provider document
      await docRef.set(provider.toJson());

      // If a user created this provider, update their user document with provider reference
      if (createdByUserId != null) {
        await _usersCollection.doc(createdByUserId).update({
          'providerId': docRef.id,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      debugPrint('Successfully created healthcare provider: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating healthcare provider: $e');
      rethrow;
    }
  }

  /// Get a healthcare provider by ID
  Future<HealthcareProviderModel?> getProvider(String providerId) async {
    try {
      final doc = await _providersCollection.doc(providerId).get();
      if (!doc.exists) return null;
      return HealthcareProviderModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting provider: $e');
      rethrow;
    }
  }

  /// Find a healthcare provider by Google Places ID
  /// Returns the provider if it exists, null otherwise
  Future<HealthcareProviderModel?> getProviderByPlaceId(String placeId) async {
    try {
      final querySnapshot = await _providersCollection
          .where('placeId', isEqualTo: placeId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      return HealthcareProviderModel.fromJson(querySnapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error finding provider by placeId: $e');
      rethrow;
    }
  }

  /// Get a healthcare provider by ID as a stream
  Stream<HealthcareProviderModel?> getProviderStream(String providerId) {
    return _providersCollection.doc(providerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return HealthcareProviderModel.fromJson(doc.data()!);
    });
  }

  /// Find nearby healthcare providers within a specified radius
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> findNearbyProviders({
    required double lat,
    required double lng,
    required double radiusInKm,
    ProviderType? filterByType,
    bool onlyVerified = true,
  }) {
    try {
      final geoCollection = GeoCollectionReference(_providersCollection);
      final center = GeoFirePoint(GeoPoint(lat, lng));

      final stream = geoCollection.subscribeWithin(
        center: center,
        radiusInKm: radiusInKm,
        field: 'geo',
        geopointFrom: (data) =>
            (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
        strictMode: true,
      );

      // Apply additional filters
      return stream.map((docs) {
        return docs.where((doc) {
          final data = doc.data();
          if (data == null) return false;

          // Filter by verification status
          if (onlyVerified && !(data['isVerified'] as bool? ?? false)) {
            return false;
          }

          // Filter by active status
          if (!(data['isActive'] as bool? ?? true)) {
            return false;
          }

          // Filter by provider type
          if (filterByType != null &&
              data['providerType'] != filterByType.toJson()) {
            return false;
          }

          return true;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error finding nearby providers: $e');
      rethrow;
    }
  }

  /// Add a doctor to a healthcare provider
  Future<void> addDoctorToProvider({
    required String providerId,
    required String doctorUserId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final providerDoc = await transaction.get(_providersCollection.doc(providerId));
        if (!providerDoc.exists) {
          throw Exception('Provider not found');
        }

        final currentDoctors = List<String>.from(
          providerDoc.data()!['associatedDoctors'] as List? ?? [],
        );

        // Check if doctor is already associated
        if (currentDoctors.contains(doctorUserId)) {
          debugPrint('Doctor $doctorUserId is already associated with provider $providerId');
          return;
        }

        // Add doctor to provider's associated doctors list
        currentDoctors.add(doctorUserId);

        transaction.update(_providersCollection.doc(providerId), {
          'associatedDoctors': currentDoctors,
          'totalDoctors': currentDoctors.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update user document with provider reference
        transaction.update(_usersCollection.doc(doctorUserId), {
          'providerId': providerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('Successfully added doctor $doctorUserId to provider $providerId');
    } catch (e) {
      debugPrint('Error adding doctor to provider: $e');
      rethrow;
    }
  }

  /// Remove a doctor from a healthcare provider
  Future<void> removeDoctorFromProvider({
    required String providerId,
    required String doctorUserId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final providerDoc = await transaction.get(_providersCollection.doc(providerId));
        if (!providerDoc.exists) {
          throw Exception('Provider not found');
        }

        final currentDoctors = List<String>.from(
          providerDoc.data()!['associatedDoctors'] as List? ?? [],
        );

        // Remove doctor from list
        currentDoctors.remove(doctorUserId);

        transaction.update(_providersCollection.doc(providerId), {
          'associatedDoctors': currentDoctors,
          'totalDoctors': currentDoctors.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Remove provider reference from user document
        transaction.update(_usersCollection.doc(doctorUserId), {
          'providerId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('Successfully removed doctor $doctorUserId from provider $providerId');
    } catch (e) {
      debugPrint('Error removing doctor from provider: $e');
      rethrow;
    }
  }

  /// Get all doctors associated with a provider
  Stream<List<UserModel>> getAssociatedDoctors(String providerId) {
    return _providersCollection.doc(providerId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null) return [];

      final doctorIds = List<String>.from(data['associatedDoctors'] as List? ?? []);
      if (doctorIds.isEmpty) return [];

      // Fetch all doctor user documents
      final doctors = <UserModel>[];
      for (final doctorId in doctorIds) {
        try {
          final userDoc = await _usersCollection.doc(doctorId).get();
          if (userDoc.exists && userDoc.data() != null) {
            doctors.add(UserModel.fromJson(userDoc.data()!));
          }
        } catch (e) {
          debugPrint('Error fetching doctor $doctorId: $e');
        }
      }

      return doctors;
    });
  }

  /// Update healthcare provider information
  Future<void> updateProvider({
    required String providerId,
    String? organizationName,
    ProviderType? providerType,
    String? phoneNumber,
    String? email,
    String? website,
    Map<String, String>? operatingHours,
    List<String>? servicesOffered,
    bool? isVerified,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (organizationName != null) updateData['organizationName'] = organizationName;
      if (providerType != null) updateData['providerType'] = providerType.toJson();
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (email != null) updateData['email'] = email;
      if (website != null) updateData['website'] = website;
      if (operatingHours != null) updateData['operatingHours'] = operatingHours;
      if (servicesOffered != null) updateData['servicesOffered'] = servicesOffered;
      if (isVerified != null) updateData['isVerified'] = isVerified;
      if (isActive != null) updateData['isActive'] = isActive;

      await _providersCollection.doc(providerId).update(updateData);
      debugPrint('Successfully updated provider $providerId');
    } catch (e) {
      debugPrint('Error updating provider: $e');
      rethrow;
    }
  }

  /// Update provider location (will regenerate geohash)
  Future<void> updateProviderLocation({
    required String providerId,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));

      await _providersCollection.doc(providerId).update({
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'geo': geoFirePoint.data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Successfully updated location for provider $providerId');
    } catch (e) {
      debugPrint('Error updating provider location: $e');
      rethrow;
    }
  }

  /// Get all providers (for admin use)
  Stream<List<HealthcareProviderModel>> getAllProviders({
    bool? isVerified,
    bool? isActive,
    ProviderType? providerType,
  }) {
    Query<Map<String, dynamic>> query = _providersCollection;

    if (isVerified != null) {
      query = query.where('isVerified', isEqualTo: isVerified);
    }
    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }
    if (providerType != null) {
      query = query.where('providerType', isEqualTo: providerType.toJson());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => HealthcareProviderModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Increment blood donations received counter
  Future<void> incrementBloodDonations(String providerId) async {
    try {
      await _providersCollection.doc(providerId).update({
        'totalBloodDonationsReceived': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing blood donations: $e');
      rethrow;
    }
  }
}

/// FIRESTORE COMPOSITE INDEX REQUIRED:
/// 
/// To make the geospatial radius queries work efficiently, you MUST create
/// a composite index in the Firebase Console:
/// 
/// Collection: healthcare_providers
/// Fields:
///   - geo.geohash (Ascending)
///   - geo.geopoint (Ascending)
/// Query scope: Collection
/// 
/// The index will be automatically suggested by Firebase when you first run
/// a geospatial query. You can click the link in the error message to
/// automatically create the index, or create it manually in the Firebase Console.
