import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/nav.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_picker/country_picker.dart';
import 'package:hema/services/healthcare_provider_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hema/models/provider_verification_model.dart';

/// Healthcare provider onboarding page
class ProviderOnboardingPage extends StatefulWidget {
  const ProviderOnboardingPage({super.key});

  @override
  State<ProviderOnboardingPage> createState() => _ProviderOnboardingPageState();
}

class _ProviderOnboardingPageState extends State<ProviderOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form data
  String? _facilityName;
  String? _facilityAddress;
  String? _facilityPlaceId;
  double? _facilityLatitude;
  double? _facilityLongitude;
  PlatformFile? _licenseFile;
  String? _selectedCountry;
  String? _selectedCountryCode;
  String? _selectedCity;
  
  // Text controllers
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _facilityController = TextEditingController();
  
  // Autocomplete suggestions
  List<Map<String, dynamic>> _citySuggestions = [];
  List<Map<String, dynamic>> _facilitySuggestions = [];
  bool _isCityLoading = false;
  bool _isFacilityLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  void _nextPage() {
    debugPrint('_nextPage called. Current page: $_currentPage');
    if (_currentPage == 4) {
      // Page 4 is the review page (after uploading license)
      // Go directly to home
      debugPrint('Completing onboarding from review page...');
      _completeOnboarding();
    } else if (_currentPage == 5) {
      // Page 5 is the welcome page (after skipping license)
      // Go to home
      debugPrint('Completing onboarding from welcome page...');
      _completeOnboarding();
    } else if (_currentPage < 5) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication error. Please log in again.')),
          );
        }
        return;
      }

      // Debug: Print all facility data
      debugPrint('=== Validating Facility Data ===');
      debugPrint('Facility Name: $_facilityName');
      debugPrint('Facility Address: $_facilityAddress');
      debugPrint('Facility Latitude: $_facilityLatitude');
      debugPrint('Facility Longitude: $_facilityLongitude');
      debugPrint('Selected Country: $_selectedCountry');
      debugPrint('Selected Country Code: $_selectedCountryCode');
      debugPrint('Selected City: $_selectedCity');
      debugPrint('================================');

      // Validate required data
      if (_facilityName == null || _facilityAddress == null || 
          _facilityLatitude == null || _facilityLongitude == null ||
          _selectedCountry == null || _selectedCountryCode == null || _selectedCity == null) {
        debugPrint('Error: Missing required facility data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Missing facility information. Please go back and complete all steps.')),
          );
        }
        return;
      }

      // Upload license file to Firebase Storage if provided
      String? licenseUrl;
      String? licenseStoragePath;
      if (_licenseFile != null) {
        try {
          final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_${_licenseFile!.name}';
          licenseStoragePath = 'provider_licenses/$fileName';
          
          final storageRef = FirebaseStorage.instance.ref().child(licenseStoragePath);
          
          // Upload file bytes with metadata
          if (_licenseFile!.bytes != null) {
            // Determine content type from file extension
            final extension = _licenseFile!.extension?.toLowerCase();
            String contentType = 'application/octet-stream';
            if (extension == 'pdf') {
              contentType = 'application/pdf';
            } else if (extension == 'jpg' || extension == 'jpeg') {
              contentType = 'image/jpeg';
            } else if (extension == 'png') {
              contentType = 'image/png';
            }
            
            final metadata = SettableMetadata(contentType: contentType);
            await storageRef.putData(_licenseFile!.bytes!, metadata);
          } else {
            debugPrint('Error: License file has no bytes to upload');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error uploading license file')),
              );
            }
            return;
          }
          
          // Get download URL
          licenseUrl = await storageRef.getDownloadURL();
          debugPrint('License uploaded successfully: $licenseUrl');
        } catch (e) {
          debugPrint('Error uploading license file: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading license: $e')),
            );
          }
          return;
        }
      }

      final now = DateTime.now();
      // Parse firstName and surname from displayName
      final displayNameParts = (user.displayName ?? '').split(' ');
      final firstName = displayNameParts.isNotEmpty ? displayNameParts.first : '';
      final surname = displayNameParts.length > 1 ? displayNameParts.sublist(1).join(' ') : '';

      // Check if facility already exists using place_id
      final providerService = HealthcareProviderService();
      String providerId;
      
      if (_facilityPlaceId != null) {
        final existingProvider = await providerService.getProviderByPlaceId(_facilityPlaceId!);
        
        if (existingProvider != null) {
          // Facility exists, add user to associatedDoctors
          providerId = existingProvider.id;
          debugPrint('Facility already exists with ID: $providerId. Adding user to associatedDoctors.');
          
          await providerService.addDoctorToProvider(
            providerId: providerId,
            doctorUserId: user.uid,
          );
        } else {
          // Facility doesn't exist, create new one
          providerId = await providerService.createProvider(
            organizationName: _facilityName!,
            providerType: ProviderType.hospital, // Default to hospital, can be updated later
            country: _selectedCountry!,
            countryCode: _selectedCountryCode!,
            city: _selectedCity!,
            address: _facilityAddress!,
            latitude: _facilityLatitude!,
            longitude: _facilityLongitude!,
            placeId: _facilityPlaceId,
            licenseFileUrl: licenseUrl,
            createdByUserId: user.uid,
          );
          debugPrint('New healthcare provider created with ID: $providerId');
        }
      } else {
        // No place_id, create new facility (shouldn't happen in normal flow)
        providerId = await providerService.createProvider(
          organizationName: _facilityName!,
          providerType: ProviderType.hospital,
          country: _selectedCountry!,
          countryCode: _selectedCountryCode!,
          city: _selectedCity!,
          address: _facilityAddress!,
          latitude: _facilityLatitude!,
          longitude: _facilityLongitude!,
          placeId: _facilityPlaceId,
          licenseFileUrl: licenseUrl,
          createdByUserId: user.uid,
        );
        debugPrint('New healthcare provider created with ID: $providerId (no place_id)');
      }

      // Create user model with reference to the healthcare provider
      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? '',
        firstName: firstName,
        surname: surname,
        userType: UserType.provider,
        createdAt: now,
        updatedAt: now,
        providerId: providerId, // Reference to healthcare provider
        organizationName: _facilityName,
        providerType: ProviderType.hospital,
        licenseFileUrl: licenseUrl,
        country: _selectedCountry,
        countryCode: _selectedCountryCode,
        city: _selectedCity,
        address: _facilityAddress,
        isVerified: false, // Needs admin verification
        isAccountActive: false, // Will be activated after verification
        onboarded: true, // Mark onboarding as complete
      );

      // Save user document to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userModel.toJson());

      // Create provider verification document if license was uploaded
      if (_licenseFile != null && licenseUrl != null && licenseStoragePath != null) {
        final verificationId = FirebaseFirestore.instance
            .collection('provider_verification')
            .doc()
            .id;
        
        final verification = ProviderVerificationModel(
          id: verificationId,
          userId: user.uid,
          providerId: providerId,
          organizationName: _facilityName!,
          providerType: ProviderType.hospital,
          licenseStoragePath: licenseStoragePath,
          licenseDownloadUrl: licenseUrl,
          status: VerificationStatus.pending,
          createdAt: now,
          updatedAt: now,
        );

        await FirebaseFirestore.instance
            .collection('provider_verification')
            .doc(verificationId)
            .set(verification.toJson());
        
        debugPrint('Provider verification document created with ID: $verificationId');
      }

      debugPrint('Provider onboarding complete! User and provider saved to Firestore.');

      // Navigate to provider home page
      if (mounted) {
        context.go(AppRoutes.providerHome);
      }
    } catch (e) {
      debugPrint('Error saving provider data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    }
  }

  // Fetch city suggestions from Firebase Function
  Future<void> _fetchCitySuggestions(String input) async {
    if (input.trim().isEmpty || _selectedCountryCode == null) {
      setState(() {
        _citySuggestions = [];
        _isCityLoading = false;
      });
      return;
    }

    setState(() => _isCityLoading = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('googlePlacesAutocomplete');
      final result = await callable.call({
        'input': input.trim(),
        'locationType': 'city',
        'regionCode': _selectedCountryCode!,
      });
      
      final suggestions = (result.data['suggestions'] as List)
          .map((s) => {
                'placeId': s['placeId'] as String,
                'description': s['description'] as String,
              })
          .toList();

      if (mounted) {
        setState(() {
          _citySuggestions = suggestions;
          _isCityLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching city suggestions: $e');
      if (mounted) {
        setState(() {
          _citySuggestions = [];
          _isCityLoading = false;
        });
      }
    }
  }

  // Fetch facility suggestions from Firebase Function
  Future<void> _fetchFacilitySuggestions(String input) async {
    debugPrint('_fetchFacilitySuggestions called with input: "$input"');
    debugPrint('Selected country code: $_selectedCountryCode, Selected city: $_selectedCity');
    
    if (input.trim().isEmpty || _selectedCountryCode == null || _selectedCity == null) {
      debugPrint('Skipping facility fetch - empty input or missing location context');
      setState(() {
        _facilitySuggestions = [];
        _isFacilityLoading = false;
      });
      return;
    }

    setState(() => _isFacilityLoading = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('googlePlacesAutocomplete');
      debugPrint('Calling cloud function with: input="${input.trim()}", locationType=facility, regionCode=$_selectedCountryCode, cityContext=$_selectedCity');
      
      final result = await callable.call({
        'input': input.trim(),
        'locationType': 'facility',
        'regionCode': _selectedCountryCode!,
        'cityContext': _selectedCity!,
      });
      
      debugPrint('Cloud function response: ${result.data}');
      
      final suggestions = (result.data['suggestions'] as List)
          .map((s) => {
                'placeId': s['placeId'] as String,
                'description': s['description'] as String,
                'lat': s['lat'], // Include latitude
                'lng': s['lng'], // Include longitude
              })
          .toList();

      debugPrint('Parsed ${suggestions.length} facility suggestions with coordinates');

      if (mounted) {
        setState(() {
          _facilitySuggestions = suggestions;
          _isFacilityLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching facility suggestions: $e');
      if (mounted) {
        setState(() {
          _facilitySuggestions = [];
          _isFacilityLoading = false;
        });
      }
    }
  }

  bool _canProceed() {
    bool canProceed;
    switch (_currentPage) {
      case 0:
        canProceed = _selectedCountry != null && _selectedCountryCode != null;
        break;
      case 1:
        canProceed = _selectedCity != null && _selectedCity!.isNotEmpty;
        break;
      case 2:
        canProceed = _facilityName != null && _facilityName!.isNotEmpty;
        break;
      case 3:
        canProceed = _licenseFile != null;
        break;
      default:
        canProceed = true;
    }
    debugPrint('_canProceed() for page $_currentPage: $canProceed');
    return canProceed;
  }

  Future<void> _pickLicenseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _licenseFile = result.files.first;
        });
        debugPrint('License file selected: ${_licenseFile!.name}');
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: isDark
                ? [Color(0xFF2C1818), Color(0xFF1A1C1E), Color(0xFF1A1C1E)]
                : [Color(0xFFF1CACA), Color(0xFFFBF1F1), Color(0xFFF7F7F7)],
            stops: [0.00, 0.61, 1.00],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        if (_currentPage > 0) {
                          _previousPage();
                        } else {
                          context.pop();
                        }
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: AppSpacing.horizontalMd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / 6,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildCountryPage(),
                    _buildCityPage(),
                    _buildFacilityPage(),
                    _buildLicenseUploadPage(),
                    _buildReviewPage(),
                    _buildWelcomeNoLicensePage(),
                  ],
                ),
              ),

              // Continue button
              Padding(
                padding: AppSpacing.paddingMd,
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Padding(
                    padding: EdgeInsets.all(0),
                    child: ElevatedButton(
                        onPressed: _canProceed() ? _nextPage : null,
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            disabledBackgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            minimumSize: const Size(0, 45)),
                        child: Text(
                            _currentPage == 4 || _currentPage == 5 ? 'Go to Home' : 'Continue',
                            style: context.textStyles.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What country is your organization in?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us verify your license and connect you with patients.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              final screenHeight = MediaQuery.of(context).size.height;
              showCountryPicker(
                context: context,
                showPhoneCode: false,
                countryListTheme: CountryListThemeData(
                  bottomSheetHeight: screenHeight * 0.9,
                ),
                onSelect: (Country country) {
                  setState(() {
                    _selectedCountry = country.name;
                    _selectedCountryCode = country.countryCode;
                  });
                },
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.public,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Country',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCountry ?? 'Select your country',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: _selectedCountry != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontWeight: _selectedCountry != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What city is your organization in?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your city name to help patients find you.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildPlacesAutocomplete(
            controller: _cityController,
            hintText: 'e.g., London',
            icon: Icons.location_city,
            suggestions: _citySuggestions,
            isLoading: _isCityLoading,
            onChanged: _fetchCitySuggestions,
            onSuggestionSelected: (suggestion) async {
              final description = suggestion['description'] ?? '';
              // Extract city name (first part before comma)
              final cityName = description.split(',').first.trim();
              _cityController.text = cityName;
              setState(() {
                _selectedCity = cityName;
                _citySuggestions = [];
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'Type in your healthcare facility name',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for your hospital, clinic, or healthcare facility. The name and address will be auto-filled.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildPlacesAutocomplete(
            controller: _facilityController,
            hintText: 'e.g., City General Hospital',
            icon: Icons.local_hospital,
            suggestions: _facilitySuggestions,
            isLoading: _isFacilityLoading,
            onChanged: _fetchFacilitySuggestions,
            onSuggestionSelected: (suggestion) async {
              debugPrint('Suggestion selected: $suggestion');
              
              final fullDescription = suggestion['description'] ?? '';
              final placeId = suggestion['placeId'] as String;
              // Extract facility name (first part before comma)
              final facilityName = fullDescription.split(',').first.trim();
              
              debugPrint('Extracted data - Name: $facilityName, PlaceId: $placeId');
              debugPrint('Fetching coordinates from getPlaceDetails cloud function...');
              
              // Clear suggestions and show loading
              setState(() {
                _facilitySuggestions = [];
                _isFacilityLoading = true;
              });
              
              try {
                // Call getPlaceDetails to fetch coordinates
                final functions = FirebaseFunctions.instance;
                final callable = functions.httpsCallable('getPlaceDetails');
                final result = await callable.call({'placeId': placeId});
                
                final lat = result.data['lat'];
                final lng = result.data['lng'];
                final name = result.data['name'] ?? facilityName;
                
                debugPrint('Place details received - Lat: $lat, Lng: $lng, Name: $name');
                
                _facilityController.text = fullDescription;
                setState(() {
                  _facilityName = name.isNotEmpty ? name : facilityName;
                  _facilityAddress = fullDescription;
                  _facilityPlaceId = placeId;
                  _facilityLatitude = lat is num ? lat.toDouble() : null;
                  _facilityLongitude = lng is num ? lng.toDouble() : null;
                  _isFacilityLoading = false;
                });
                
                debugPrint('State updated - _facilityLatitude: $_facilityLatitude, _facilityLongitude: $_facilityLongitude');
              } catch (e) {
                debugPrint('Error fetching place details: $e');
                setState(() {
                  _isFacilityLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error fetching facility details: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesAutocomplete({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required List<Map<String, dynamic>> suggestions,
    required bool isLoading,
    required Function(String) onChanged,
    required Future<void> Function(Map<String, dynamic>) onSuggestionSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: context.textStyles.bodyLarge?.copyWith(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              suffixIcon: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  : controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            setState(() {
                              onChanged('');
                            });
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.white,
              contentPadding: const EdgeInsets.all(20),
            ),
            onChanged: (value) {
              setState(() {
                onChanged(value);
              });
            },
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                height: 1,
              ),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return InkWell(
                  onTap: () => onSuggestionSelected(suggestion),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion['description'] ?? '',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLicenseUploadPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  'Upload Operating License',
                  style: context.textStyles.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _licenseFile = null;
                  });
                  // Navigate to page 5 (welcome without license page)
                  _pageController.animateToPage(
                    5,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Skip',
                  style: context.textStyles.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload your healthcare provider operating license. The details must match "${_facilityName ?? 'your facility name'}".',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Upload button
          GestureDetector(
            onTap: _pickLicenseFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _licenseFile != null
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : (isDark ? Colors.grey[850] : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _licenseFile != null
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: _licenseFile != null ? 2 : 1,
                  style: _licenseFile == null ? BorderStyle.solid : BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _licenseFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                    size: 64,
                    color: _licenseFile != null
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _licenseFile != null ? 'License Uploaded' : 'Tap to Upload License',
                    style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _licenseFile != null
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (_licenseFile != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _licenseFile!.name,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _licenseFile != null ? 'Tap to change file' : 'Supported formats: PDF, JPG, PNG',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Information box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your operating license will be verified by our team. Please ensure the document is clear and the organization name matches what you entered.',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Document Under Review',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your operating license will be reviewed by our team. We will notify you once your account is activated.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'What happens next?',
                        style: context.textStyles.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ReviewStepItem(
                  number: '1',
                  text: 'Our team will verify your operating license',
                ),
                const SizedBox(height: 12),
                ReviewStepItem(
                  number: '2',
                  text: 'You will receive an email notification',
                ),
                const SizedBox(height: 12),
                ReviewStepItem(
                  number: '3',
                  text: 'Once approved, your account will be activated',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPage(int pageNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Step $pageNumber of 5',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This page is coming soon. For now, you can continue to the next step.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeNoLicensePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Hema!',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your account has been created successfully. However, you will need to upload and verify your operating license before you can request blood from donors.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'License Required',
                        style: context.textStyles.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'To request blood and access full features, please upload your operating license from your profile settings and wait for verification.',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Review step item widget
class ReviewStepItem extends StatelessWidget {
  final String number;
  final String text;

  const ReviewStepItem({
    super.key,
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white : Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
