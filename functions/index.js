const functions = require('firebase-functions');
const {onCall} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const axios = require('axios');

// Define the Google Places API Key secret
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

// Google Places Autocomplete Proxy with Coordinates
exports.googlePlacesAutocomplete = functions.https.onCall(async (data, context) => {
  try {
    const { input, locationType, regionCode, cityContext } = data;
    
    if (!input || typeof input !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'The function must be called with a valid input string.'
      );
    }

    // Get the Google API key from Firebase config
    const googleApiKey = functions.config().google?.places_api_key;
    
    if (!googleApiKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Google Places API key is not configured.'
      );
    }

    // Build request body based on location type
    const requestBody = {
      input: cityContext ? `${input}, ${cityContext}` : input,
    };

    // Add region code if provided
    if (regionCode) {
      requestBody.includedRegionCodes = [regionCode.toLowerCase()];
    }

    // Add type filtering based on locationType
    if (locationType === 'city') {
      requestBody.includedPrimaryTypes = ['locality', 'administrative_area_level_3'];
    } else if (locationType === 'neighborhood') {
      requestBody.includedPrimaryTypes = ['neighborhood', 'sublocality', 'locality'];
    } else if (locationType === 'address') {
      // For addresses, include a broader range of types to capture establishments,
      // buildings, and specific locations (especially useful in areas with sparse data)
      requestBody.includedPrimaryTypes = [
        'street_address', 
        'premise', 
        'subpremise',
        'route',
        'establishment',
        'point_of_interest',
        'hospital',
        'health'
      ];
    } else if (locationType === 'facility') {
      // For healthcare facilities, search for hospitals, clinics, and health-related establishments
      requestBody.includedPrimaryTypes = [
        'hospital',
        'health',
        'doctor',
        'clinic',
        'pharmacy',
        'medical_lab'
      ];
    }

    console.log(`Calling Places API with locationType=${locationType}, input="${requestBody.input}", regionCode=${regionCode}`);

    // Call Google Places Autocomplete API (New)
    const response = await axios.post(
      'https://places.googleapis.com/v1/places:autocomplete',
      requestBody,
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleApiKey,
        },
      }
    );

    console.log(`Places API returned ${response.data.suggestions?.length || 0} suggestions`);

    // Extract information from suggestions and fetch coordinates for each
    const suggestions = await Promise.all(
      (response.data.suggestions || []).map(async (suggestion) => {
        const placePrediction = suggestion.placePrediction;
        const placeId = placePrediction?.placeId || '';
        
        let lat = null;
        let lng = null;
        
        // Fetch coordinates using Place Details API
        if (placeId) {
          try {
            const detailsResponse = await axios.get(
              `https://places.googleapis.com/v1/places/${placeId}`,
              {
                headers: {
                  'Content-Type': 'application/json',
                  'X-Goog-Api-Key': googleApiKey,
                  'X-Goog-FieldMask': 'location',
                },
              }
            );
            
            const location = detailsResponse.data?.location;
            if (location) {
              lat = location.latitude;
              lng = location.longitude;
            }
          } catch (detailsError) {
            console.error(`Error fetching details for place ${placeId}:`, detailsError.message);
            // Continue without coordinates - will be null
          }
        }
        
        return {
          placeId,
          description: placePrediction?.text?.text || '',
          mainText: placePrediction?.structuredFormat?.mainText?.text || '',
          secondaryText: placePrediction?.structuredFormat?.secondaryText?.text || '',
          lat,
          lng,
        };
      })
    );

    return { suggestions };
  } catch (error) {
    console.error('Error in googlePlacesAutocomplete:', error);
    
    if (error.response) {
      throw new functions.https.HttpsError(
        'internal',
        `Google Places API error: ${error.response.data?.error?.message || error.message}`
      );
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'An unexpected error occurred'
    );
  }
});

// Get Place Details (coordinates) from Place ID
exports.getPlaceDetails = onCall(
  {
    secrets: [googlePlacesApiKey],
  },
  async (request) => {
    try {
      const {placeId} = request.data;
      const apiKey = googlePlacesApiKey.value();

      if (!placeId) {
        throw new functions.https.HttpsError('invalid-argument', 'placeId required.');
      }

      console.log(`Fetching place details for placeId: ${placeId}`);

      const response = await axios.get(
        `https://places.googleapis.com/v1/places/${placeId}`,
        {
          headers: {
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'id,location,displayName',
          },
        },
      );

      const result = response.data;
      console.log(`Place details response:`, JSON.stringify(result));

      if (!result.location) {
        throw new functions.https.HttpsError('not-found', 'No coordinates found for this place.');
      }

      return {
        lat: result.location.latitude,
        lng: result.location.longitude,
        name: (result.displayName && result.displayName.text) || '',
      };
    } catch (error) {
      console.error('Place Details Error:', error.message);
      if (error.response) {
        console.error('API Response Error:', error.response.data);
      }
      throw new functions.https.HttpsError('internal', error.message);
    }
  },
);

// Delete User Account and All Associated Data
exports.deleteUser = onCall(async (request) => {
  try {
    const userId = request.auth?.uid;

    if (!userId) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to delete their account.'
      );
    }

    console.log(`Starting account deletion for user: ${userId}`);

    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    const db = admin.firestore();
    const auth = admin.auth();

    // Mark user document for deletion (scheduled for 30 days)
    const deletionDate = new Date();
    deletionDate.setDate(deletionDate.getDate() + 30);

    await db.collection('users').doc(userId).update({
      markedForDeletion: true,
      deletionScheduledAt: admin.firestore.Timestamp.fromDate(deletionDate),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Delete donor documents (daytime and nighttime)
    const donorDaytimeRef = db.collection('donors').doc(`${userId}_daytime`);
    const donorNighttimeRef = db.collection('donors').doc(`${userId}_nighttime`);
    
    await Promise.all([
      donorDaytimeRef.delete(),
      donorNighttimeRef.delete(),
    ]);

    // Delete healthcare provider document if exists
    const providerDoc = await db.collection('healthcare_providers').doc(userId).get();
    if (providerDoc.exists) {
      await providerDoc.ref.delete();
    }

    // Delete user's blood requests
    const requestsSnapshot = await db
      .collection('blood_requests')
      .where('requesterId', '==', userId)
      .get();
    
    const requestDeletions = requestsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(requestDeletions);

    // Delete Firebase Auth user
    await auth.deleteUser(userId);

    console.log(`Account deletion completed for user: ${userId}. Data will be permanently deleted in 30 days.`);

    return {
      success: true,
      message: 'Account deleted. Your data will be permanently removed from our servers in 30 days.',
    };
  } catch (error) {
    console.error('Error deleting user account:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to delete account: ${error.message}`
    );
  }
});

