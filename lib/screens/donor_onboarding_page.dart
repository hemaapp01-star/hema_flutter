import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/nav.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:country_picker/country_picker.dart';
import 'package:hema/services/donor_geospatial_service.dart';

/// Donor onboarding page with 11 steps
class DonorOnboardingPage extends StatefulWidget {
  const DonorOnboardingPage({super.key});

  @override
  State<DonorOnboardingPage> createState() => _DonorOnboardingPageState();
}

class _DonorOnboardingPageState extends State<DonorOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form data
  DateTime? _dateOfBirth;
  String? _biologicalSex;
  int? _weight; // in lbs
  String? _bloodType;
  String? _selectedCountry;
  String? _selectedCountryCode;
  String? _selectedCity;
  String? _daytimeAddress;
  String? _nighttimeAddress;
  String? _daytimePlaceId;
  String? _nighttimePlaceId;
  double? _daytimeLat;
  double? _daytimeLng;
  double? _nighttimeLat;
  double? _nighttimeLng;
  
  // Text controllers
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _daytimeController = TextEditingController();
  final TextEditingController _nighttimeController = TextEditingController();
  
  // Autocomplete suggestions
  List<Map<String, dynamic>> _citySuggestions = [];
  List<Map<String, dynamic>> _daytimeSuggestions = [];
  List<Map<String, dynamic>> _nighttimeSuggestions = [];
  bool _isCityLoading = false;
  bool _isDaytimeLoading = false;
  bool _isNighttimeLoading = false;
  bool _isSavingData = false;

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    _daytimeController.dispose();
    _nighttimeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
    
    if (_currentPage < 10) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete onboarding
      _completeOnboarding();
    }
  }

  void _previousPage() {
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
    
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isSavingData) return; // Prevent multiple submissions
    
    setState(() => _isSavingData = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication error. Please log in again.')),
          );
          setState(() => _isSavingData = false);
        }
        return;
      }

      // Map blood type string to enum
      BloodType? mappedBloodType;
      if (_bloodType != null) {
        mappedBloodType = BloodType.fromJson(_bloodType!);
      }

      // Map biological sex to enum
      BiologicalSex? mappedBiologicalSex;
      if (_biologicalSex != null) {
        mappedBiologicalSex = _biologicalSex == 'Male'
            ? BiologicalSex.male
            : BiologicalSex.female;
      }

      // Create user model with all donor data
      final now = DateTime.now();
      // Parse firstName and surname from displayName
      final displayNameParts = (user.displayName ?? '').split(' ');
      final firstName = displayNameParts.isNotEmpty ? displayNameParts.first : '';
      final surname = displayNameParts.length > 1 ? displayNameParts.sublist(1).join(' ') : '';
      
      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? '',
        firstName: firstName,
        surname: surname,
        userType: UserType.donor,
        createdAt: now,
        updatedAt: now,
        // Donor-specific onboarding data
        dateOfBirth: _dateOfBirth,
        biologicalSex: mappedBiologicalSex,
        weight: _weight,
        bloodType: mappedBloodType,
        country: _selectedCountry,
        countryCode: _selectedCountryCode,
        city: _selectedCity,
        daytimeAddress: _daytimeAddress,
        nighttimeAddress: _nighttimeAddress,
        // Initialize donor tracking fields
        isAvailable: false, // Default to false, user can toggle on home page
        lastDonationDate: null,
        nextEligibleDate: null,
        totalDonations: 0,
        livesSaved: 0,
        badges: [],
        heroLevel: 0,
        onboarded: true, // Mark onboarding as complete
      );

      // Save to Firestore users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userModel.toJson());

      debugPrint('Donor saved to users collection');

      // Now geocode the place IDs and save to donors collection
      final fullName = '${firstName} ${surname}'.trim();
      await _saveToDonorsCollection(user.uid, fullName, mappedBloodType?.displayName ?? 'Unknown');

      debugPrint('Donor onboarding complete!');

      // Navigate to donor home page
      if (mounted) {
        context.go(AppRoutes.donorHome);
      }
    } catch (e) {
      debugPrint('Error saving donor data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingData = false);
      }
    }
  }

  /// Save donor to donors collection with on-device geohash generation
  Future<void> _saveToDonorsCollection(String uid, String name, String bloodGroup) async {
    try {
      // First, fetch coordinates from Place IDs using the getPlaceDetails cloud function
      if (_daytimePlaceId == null || _nighttimePlaceId == null) {
        debugPrint('Error: Missing Place IDs, cannot save to donors collection');
        throw Exception('Location Place IDs are missing. Please select valid neighborhoods again.');
      }

      debugPrint('Fetching coordinates for Place IDs...');
      debugPrint('Daytime Place ID: $_daytimePlaceId');
      debugPrint('Nighttime Place ID: $_nighttimePlaceId');

      final functions = FirebaseFunctions.instance;
      
      // Fetch daytime coordinates
      final daytimeCallable = functions.httpsCallable('getPlaceDetails');
      final daytimeResult = await daytimeCallable.call({'placeId': _daytimePlaceId});
      final daytimeLat = daytimeResult.data['lat'] as double;
      final daytimeLng = daytimeResult.data['lng'] as double;
      
      // Fetch nighttime coordinates
      final nighttimeCallable = functions.httpsCallable('getPlaceDetails');
      final nighttimeResult = await nighttimeCallable.call({'placeId': _nighttimePlaceId});
      final nighttimeLat = nighttimeResult.data['lat'] as double;
      final nighttimeLng = nighttimeResult.data['lng'] as double;

      debugPrint('✓ Coordinates fetched successfully:');
      debugPrint('Daytime: ($daytimeLat, $daytimeLng)');
      debugPrint('Nighttime: ($nighttimeLat, $nighttimeLng)');

      // Create TWO donor documents (daytime and nighttime) using geospatial service
      // Geohash is generated on-device using geoflutterfire_plus
      final geospatialService = DonorGeospatialService();
      await geospatialService.createDonorDocuments(
        uid: uid,
        name: name,
        bloodGroup: bloodGroup,
        daytimeLat: daytimeLat,
        daytimeLng: daytimeLng,
        nighttimeLat: nighttimeLat,
        nighttimeLng: nighttimeLng,
        additionalData: {
          'country': _selectedCountry,
          'countryCode': _selectedCountryCode,
          'city': _selectedCity,
          'daytimeAddress': _daytimeAddress,
          'nighttimeAddress': _nighttimeAddress,
          'isAvailable': false,
        },
      );
      
      debugPrint('✓ Donor documents created successfully in donors collection with on-device geohash');
    } catch (e) {
      debugPrint('Error saving to donors collection: $e');
      // Rethrow to prevent onboarding from completing with incomplete data
      rethrow;
    }
  }

  // Fetch city suggestions from Firebase Function
  Future<void> _fetchCitySuggestions(String input) async {
    if (input.isEmpty || _selectedCountryCode == null) {
      setState(() => _citySuggestions = []);
      return;
    }

    setState(() => _isCityLoading = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('googlePlacesAutocomplete');
      final result = await callable.call({
        'input': input,
        'locationType': 'city',
        'regionCode': _selectedCountryCode!,
      });
      
      final suggestions = (result.data['suggestions'] as List)
          .map((s) => {
                'placeId': s['placeId'] as String,
                'description': s['description'] as String,
              })
          .toList();

      setState(() {
        _citySuggestions = suggestions;
        _isCityLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching city suggestions: $e');
      setState(() {
        _citySuggestions = [];
        _isCityLoading = false;
      });
    }
  }

  // Fetch neighborhood suggestions from Firebase Function
  Future<void> _fetchNeighborhoodSuggestions(String input, bool isDaytime) async {
    if (input.isEmpty || _selectedCountryCode == null || _selectedCity == null) {
      setState(() {
        if (isDaytime) {
          _daytimeSuggestions = [];
        } else {
          _nighttimeSuggestions = [];
        }
      });
      return;
    }

    setState(() {
      if (isDaytime) {
        _isDaytimeLoading = true;
      } else {
        _isNighttimeLoading = true;
      }
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('googlePlacesAutocomplete');
      final result = await callable.call({
        'input': input,
        'locationType': 'neighborhood',
        'regionCode': _selectedCountryCode!,
        'cityContext': _selectedCity!,
      });
      
      final suggestions = (result.data['suggestions'] as List)
          .map((s) => {
                'placeId': s['placeId'] as String,
                'description': s['description'] as String,
              })
          .toList();

      setState(() {
        if (isDaytime) {
          _daytimeSuggestions = suggestions;
          _isDaytimeLoading = false;
        } else {
          _nighttimeSuggestions = suggestions;
          _isNighttimeLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error fetching neighborhood suggestions: $e');
      setState(() {
        if (isDaytime) {
          _daytimeSuggestions = [];
          _isDaytimeLoading = false;
        } else {
          _nighttimeSuggestions = [];
          _isNighttimeLoading = false;
        }
      });
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
        return _dateOfBirth != null;
      case 1:
        return _biologicalSex != null;
      case 2:
        return _weight != null && _weight! >= 110;
      case 3:
        return _bloodType != null;
      case 4:
        return _selectedCountry != null && _selectedCountryCode != null;
      case 5:
        return _selectedCity != null && _selectedCity!.isNotEmpty;
      case 6:
        return _daytimeAddress != null &&
            _daytimeAddress!.isNotEmpty &&
            _nighttimeAddress != null &&
            _nighttimeAddress!.isNotEmpty;
      default:
        return true;
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
                    value: (_currentPage + 1) / 11,
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
                    _buildDateOfBirthPage(),
                    _buildBiologicalSexPage(),
                    _buildWeightPage(),
                    _buildBloodTypePage(),
                    _buildCountryPage(),
                    _buildCityPage(),
                    _buildAddressPage(),
                    _buildWelcomeJourneyPage(),
                    _buildPlaceholderPage(9),
                    _buildPlaceholderPage(10),
                    _buildPlaceholderPage(11),
                  ],
                ),
              ),

              // Continue button (hide on page 7 - welcome journey page)
              if (_currentPage != 7)
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
                          child: Text(_currentPage < 10 ? 'Continue' : 'Complete',
                              style: context.textStyles.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
              if (_currentPage != 5) const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What is your date of birth?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You must be between 18 and 65 years old to donate blood.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Date of birth display
          GestureDetector(
            onTap: () => _showDatePicker(context),
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
                    Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date of Birth',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateOfBirth != null
                              ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                              : 'Select your date of birth',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: _dateOfBirth != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontWeight: _dateOfBirth != null
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

          if (_dateOfBirth != null) ...[
            const SizedBox(height: 24),
            _buildAgeInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildAgeInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final age = _calculateAge(_dateOfBirth!);
    final isValid = age >= 18 && age <= 65;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isValid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isValid
                  ? 'You are $age years old - eligible to donate!'
                  : 'You must be between 18 and 65 years old to donate blood.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: isValid
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiologicalSexPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What is your biological sex?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This information helps determine blood donation eligibility.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Male option
          _buildSexOption(
            'Male',
            Icons.male,
            isDark,
          ),
          const SizedBox(height: 16),

          // Female option
          _buildSexOption(
            'Female',
            Icons.female,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSexOption(String sex, IconData icon, bool isDark) {
    final isSelected = _biologicalSex == sex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _biologicalSex = sex;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[850] : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                sex,
                style: context.textStyles.titleLarge?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What is your weight?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You must weigh at least 110 lbs to donate blood.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Weight display
          GestureDetector(
            onTap: () => _showWeightPicker(context),
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
                    Icons.monitor_weight_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weight (lbs)',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weight != null
                              ? '$_weight lbs'
                              : 'Select your weight',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: _weight != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontWeight: _weight != null
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

          if (_weight != null) ...[
            const SizedBox(height: 24),
            _buildWeightInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValid = _weight! >= 110;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isValid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isValid
                  ? 'Your weight is $_weight lbs - eligible to donate!'
                  : 'You must weigh at least 110 lbs to donate blood.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: isValid
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloodTypes = BloodType.values
        .map((e) => e == BloodType.unknown ? "I don't know" : e.displayName)
        .toList();

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What is your blood type?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your blood type if you know it, or choose "I don\'t know".',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Blood type options grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: bloodTypes.length,
            itemBuilder: (context, index) {
              final bloodType = bloodTypes[index];
              final isSelected = _bloodType == bloodType;
              final isIDontKnow = bloodType == "I don't know";

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _bloodType = bloodType;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : (isDark ? Colors.grey[850] : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isIDontKnow)
                        Icon(
                          Icons.help_outline_rounded,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white60 : Colors.black54),
                          size: 28,
                        )
                      else
                        Icon(
                          Icons.bloodtype_rounded,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white60 : Colors.black54),
                          size: 28,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        bloodType,
                        textAlign: TextAlign.center,
                        style: context.textStyles.titleMedium?.copyWith(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white : Colors.black87),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: isIDontKnow ? 12 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
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
    required Function(Map<String, dynamic>) onSuggestionSelected,
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
                            onChanged('');
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
            onChanged: onChanged,
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
                              fontWeight: FontWeight.w500,
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

  Widget _buildCountryPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'What country are you in?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us connect you with people in your region.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              showCountryPicker(
                context: context,
                showPhoneCode: false,
                countryListTheme: CountryListThemeData(
                  bottomSheetHeight: MediaQuery.of(context).size.height * 0.9,
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
            'What city do you live in?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your city name to help us find donors nearby.',
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
            onSuggestionSelected: (suggestion) {
              setState(() {
                _selectedCity = suggestion['description'] ?? '';
                _cityController.text = _selectedCity ?? '';
                _citySuggestions = [];
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'Where are you during the day?',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This lets us alert you if someone near you needs help',
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Daytime neighborhood',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Just the neighborhood name will suffice (e.g., "Nottingham")',
            style: context.textStyles.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          _buildPlacesAutocomplete(
            controller: _daytimeController,
            hintText: 'e.g., Nottingham',
            icon: Icons.work_outline_rounded,
            suggestions: _daytimeSuggestions,
            isLoading: _isDaytimeLoading,
            onChanged: (value) => _fetchNeighborhoodSuggestions(value, true),
            onSuggestionSelected: (suggestion) {
              setState(() {
                _daytimeAddress = suggestion['description'] ?? '';
                _daytimePlaceId = suggestion['placeId'] as String?;
                _daytimeController.text = _daytimeAddress ?? '';
                _daytimeSuggestions = [];
              });
              debugPrint('Daytime location selected with Place ID: $_daytimePlaceId');
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Nighttime neighborhood',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Just the neighborhood name will suffice (e.g., "Downtown")',
            style: context.textStyles.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          _buildPlacesAutocomplete(
            controller: _nighttimeController,
            hintText: 'e.g., Downtown',
            icon: Icons.home_outlined,
            suggestions: _nighttimeSuggestions,
            isLoading: _isNighttimeLoading,
            onChanged: (value) => _fetchNeighborhoodSuggestions(value, false),
            onSuggestionSelected: (suggestion) {
              setState(() {
                _nighttimeAddress = suggestion['description'] ?? '';
                _nighttimePlaceId = suggestion['placeId'] as String?;
                _nighttimeController.text = _nighttimeAddress ?? '';
                _nighttimeSuggestions = [];
              });
              debugPrint('Nighttime location selected with Place ID: $_nighttimePlaceId');
            },
          ),
          const SizedBox(height: 24),
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
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We use these neighborhoods to notify you when someone nearby needs blood during work hours and off hours.',
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

  Widget _buildWelcomeJourneyPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volunteer_activism,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Your Journey',
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You are about to begin your journey in helping people. When there is a need for blood nearby, we will contact you if you are available.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.6,
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
                _buildJourneyFeature(
                  icon: Icons.notification_important,
                  title: 'Get Notified',
                  description: 'Receive alerts when someone nearby needs your blood type',
                ),
                const SizedBox(height: 16),
                _buildJourneyFeature(
                  icon: Icons.location_on,
                  title: 'Stay Local',
                  description: 'Help people in your community during their critical moments',
                ),
                const SizedBox(height: 16),
                _buildJourneyFeature(
                  icon: Icons.favorite,
                  title: 'Save Lives',
                  description: 'Each donation can save up to 3 lives',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSavingData ? null : _completeOnboarding,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSavingData
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Get Started',
                    style: context.textStyles.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildJourneyFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
            Icons.favorite,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Step $pageNumber of 11',
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

  void _showDatePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Calculate min and max dates (18-65 years old)
    final minDate = DateTime(now.year - 65, now.month, now.day);
    final maxDate = DateTime(now.year - 18, now.month, now.day);

    // Initial date (25 years ago by default)
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    'Select Date of Birth',
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Date picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _dateOfBirth = newDate;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _showWeightPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initial weight (150 lbs by default or current weight)
    int selectedWeight = _weight ?? 150;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    'Select Weight',
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _weight = selectedWeight;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Weight picker
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: selectedWeight - 50,
                ),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  selectedWeight = index + 50;
                },
                children: List.generate(
                  251, // 50 to 300 lbs
                  (index) {
                    final weight = index + 50;
                    return Center(
                      child: Text(
                        '$weight lbs',
                        style: context.textStyles.titleLarge?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
