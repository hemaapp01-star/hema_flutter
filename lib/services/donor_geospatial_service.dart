import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:flutter/foundation.dart';

/// Custom exception for geospatial operations
class GeospatialException implements Exception {
  final String message;
  GeospatialException(this.message);
  
  @override
  String toString() => 'GeospatialException: $message';
}

/// Service layer for managing donor geospatial data using geoflutterfire_plus
/// 
/// This service creates TWO documents for each donor:
/// 1. {uid}_daytime - Contains daytime location and availability
/// 2. {uid}_nighttime - Contains nighttime location and availability
/// 
/// This approach simplifies queries by allowing a single location field 'geo'
/// instead of separate geoDaytime/geoNighttime fields. Cloud functions can
/// filter by time of day after performing the geospatial query.
class DonorGeospatialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Collection reference for donors
  CollectionReference<Map<String, dynamic>> get _donorsCollection =>
      _firestore.collection('donors');

  /// Find nearby donors within a specified radius
  /// 
  /// This method queries the donors collection for all documents within the radius.
  /// The cloud function should filter results by time period (daytime/nighttime)
  /// by checking the document ID suffix (_daytime or _nighttime).
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> findNearbyDonors({
    required double lat,
    required double lng,
    required double radiusInKm,
  }) {
    try {
      // Create GeoCollectionReference
      final geoCollection = GeoCollectionReference(_donorsCollection);
      
      // Create center point for radius query
      final center = GeoFirePoint(GeoPoint(lat, lng));
      
      // Query for donors within radius
      // strictMode: true filters out false positives outside the actual circle
      final stream = geoCollection.subscribeWithin(
        center: center,
        radiusInKm: radiusInKm,
        field: 'geo',
        geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
        strictMode: true,
      );
      
      debugPrint('Listening for donors within ${radiusInKm}km of ($lat, $lng)');
      
      return stream;
    } catch (e) {
      debugPrint('Error finding nearby donors: $e');
      throw GeospatialException('Failed to find nearby donors: $e');
    }
  }

  /// Create two donor documents (daytime and nighttime) in the donors collection
  /// 
  /// This method should be called at the end of donor onboarding to create
  /// both donor documents with location-specific data.
  /// 
  /// Document structure:
  /// - donors/{uid}_daytime: Contains daytime location + common donor info
  /// - donors/{uid}_nighttime: Contains nighttime location + common donor info
  Future<void> createDonorDocuments({
    required String uid,
    required String name,
    required String bloodGroup,
    required double daytimeLat,
    required double daytimeLng,
    required double nighttimeLat,
    required double nighttimeLng,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create GeoFirePoints for both locations
      final daytimeGeoPoint = GeoFirePoint(GeoPoint(daytimeLat, daytimeLng));
      final nighttimeGeoPoint = GeoFirePoint(GeoPoint(nighttimeLat, nighttimeLng));
      
      // Common donor data
      final commonData = {
        'uid': uid,
        'name': name,
        'bloodGroup': bloodGroup,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        ...?additionalData,
      };
      
      // Create daytime document
      final daytimeData = {
        ...commonData,
        'geo': daytimeGeoPoint.data,
        'timePeriod': 'daytime',
      };
      
      // Create nighttime document
      final nighttimeData = {
        ...commonData,
        'geo': nighttimeGeoPoint.data,
        'timePeriod': 'nighttime',
      };
      
      // Write both documents
      final batch = _firestore.batch();
      batch.set(_donorsCollection.doc('${uid}_daytime'), daytimeData);
      batch.set(_donorsCollection.doc('${uid}_nighttime'), nighttimeData);
      await batch.commit();
      
      debugPrint('Successfully created daytime and nighttime donor documents for $uid');
    } catch (e) {
      debugPrint('Error creating donor documents: $e');
      throw GeospatialException('Failed to create donor documents: $e');
    }
  }

  /// Update availability status for both daytime and nighttime documents
  Future<void> updateAvailability({
    required String uid,
    required bool isAvailable,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_donorsCollection.doc('${uid}_daytime'), {'isAvailable': isAvailable});
      batch.update(_donorsCollection.doc('${uid}_nighttime'), {'isAvailable': isAvailable});
      await batch.commit();
      
      debugPrint('Successfully updated availability for donor $uid to $isAvailable');
    } catch (e) {
      debugPrint('Error updating availability: $e');
      throw GeospatialException('Failed to update availability: $e');
    }
  }

  /// Update location for a specific time period
  Future<void> updateLocation({
    required String uid,
    required double lat,
    required double lng,
    required bool isDaytime,
  }) async {
    try {
      final geoFirePoint = GeoFirePoint(GeoPoint(lat, lng));
      final docId = isDaytime ? '${uid}_daytime' : '${uid}_nighttime';
      
      await _donorsCollection.doc(docId).update({
        'geo': geoFirePoint.data,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Successfully updated ${isDaytime ? 'daytime' : 'nighttime'} location for donor $uid');
    } catch (e) {
      debugPrint('Error updating location: $e');
      throw GeospatialException('Failed to update location: $e');
    }
  }
}

/// FIRESTORE COMPOSITE INDEX REQUIRED:
/// 
/// To make the geospatial radius queries work efficiently, you MUST create
/// ONE composite index in the Firebase Console:
/// 
/// Collection: donors
/// Fields:
///   - geo.geohash (Ascending)
///   - geo.geopoint (Ascending)
/// Query scope: Collection
/// 
/// This single index works for both daytime and nighttime queries since all
/// donor documents use the same 'geo' field structure. The cloud function
/// filters results by time period after the geospatial query completes.
/// 
/// The index will be automatically suggested by Firebase when you first run
/// a geospatial query. You can click the link in the error message to
/// automatically create the index, or create it manually in the Firebase Console:
/// 
/// Firebase Console → Firestore Database → Indexes → Composite → Create Index
/// 
/// Note: Index creation can take several minutes. The app will throw an error
/// until the index is fully built.
