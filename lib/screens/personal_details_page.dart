import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hema/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hema/services/donor_geospatial_service.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// Personal details page for donors to view and edit their profile information
class PersonalDetailsPage extends StatefulWidget {
  const PersonalDetailsPage({super.key});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Form data
  DateTime? _dateOfBirth;
  String? _biologicalSex;
  int? _weight;
  String? _bloodType;
  String? _daytimeAddress;
  String? _nighttimeAddress;
  
  // Store coordinates for selected addresses
  double? _daytimeLat;
  double? _daytimeLng;
  double? _nighttimeLat;
  double? _nighttimeLng;
  
  // Geospatial service
  final _geoService = DonorGeospatialService();

  // Text controllers
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _daytimeController = TextEditingController();
  final TextEditingController _nighttimeController = TextEditingController();
  
  // Autocomplete suggestions
  List<Map<String, dynamic>> _daytimeSuggestions = [];
  List<Map<String, dynamic>> _nighttimeSuggestions = [];
  final FocusNode _daytimeFocus = FocusNode();
  final FocusNode _nighttimeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not logged in')),
          );
          context.pop();
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final userData = UserModel.fromJson(doc.data()!);
        setState(() {
          _dateOfBirth = userData.dateOfBirth;
          _biologicalSex = userData.biologicalSex?.name;
          _weight = userData.weight;
          _bloodType = userData.bloodType?.displayName;
          _daytimeAddress = userData.daytimeAddress;
          _nighttimeAddress = userData.nighttimeAddress;

          _weightController.text = _weight?.toString() ?? '';
          _daytimeController.text = _daytimeAddress ?? '';
          _nighttimeController.text = _nighttimeAddress ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Map blood type string to enum
      BloodType? mappedBloodType;
      if (_bloodType != null) {
      if (_bloodType != null) {
        mappedBloodType = BloodType.fromJson(_bloodType!);
      }
      }

      // Map biological sex to enum
      BiologicalSex? mappedBiologicalSex;
      if (_biologicalSex != null) {
        mappedBiologicalSex = _biologicalSex == 'male'
            ? BiologicalSex.male
            : BiologicalSex.female;
      }

      // Get user document to fetch full name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) throw Exception('User document not found');
      
      final userData = UserModel.fromJson(userDoc.data()!);
      final fullName = '${userData.firstName} ${userData.surname}';

      // Update users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'dateOfBirth':
            _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
        'biologicalSex': mappedBiologicalSex?.toJson(),
        'weight': _weight,
        'bloodType': mappedBloodType?.toJson(),
        'daytimeAddress': _daytimeAddress,
        'nighttimeAddress': _nighttimeAddress,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Prepare common donor data updates (name and bloodGroup)
      final donorCommonUpdates = <String, dynamic>{
        'name': fullName,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };
      
      // Add bloodGroup if it's set and not "I don't know"
      if (mappedBloodType != null && mappedBloodType != BloodType.unknown) {
        donorCommonUpdates['bloodGroup'] = mappedBloodType.displayName;
      }
      
      // Update donors collection with geohash if both addresses have coordinates
      if (_daytimeLat != null && _daytimeLng != null && 
          _nighttimeLat != null && _nighttimeLng != null) {
        debugPrint('Updating donor geospatial data with new addresses');
        
        // Create GeoFirePoints for both locations
        final daytimeGeoPoint = GeoFirePoint(GeoPoint(_daytimeLat!, _daytimeLng!));
        final nighttimeGeoPoint = GeoFirePoint(GeoPoint(_nighttimeLat!, _nighttimeLng!));
        
        // Update daytime document with geo + common fields
        await FirebaseFirestore.instance
            .collection('donors')
            .doc('${user.uid}_daytime')
            .update({
          'geo': daytimeGeoPoint.data,
          'daytimeAddress': _daytimeAddress,
          ...donorCommonUpdates,
        });
        
        // Update nighttime document with geo + common fields
        await FirebaseFirestore.instance
            .collection('donors')
            .doc('${user.uid}_nighttime')
            .update({
          'geo': nighttimeGeoPoint.data,
          'nighttimeAddress': _nighttimeAddress,
          ...donorCommonUpdates,
        });
        
        debugPrint('Successfully updated geospatial data and common fields in donors collection');
      } else {
        // Even if coordinates aren't available, update name and bloodGroup in both documents
        debugPrint('Updating donor common fields (name, bloodGroup) without geospatial changes');
        
        final batch = FirebaseFirestore.instance.batch();
        
        batch.update(
          FirebaseFirestore.instance.collection('donors').doc('${user.uid}_daytime'),
          donorCommonUpdates,
        );
        
        batch.update(
          FirebaseFirestore.instance.collection('donors').doc('${user.uid}_nighttime'),
          donorCommonUpdates,
        );
        
        await batch.commit();
        debugPrint('Successfully updated common fields in donors collection');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal details updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final minDate = DateTime(now.year - 65, now.month, now.day);
    final maxDate = DateTime(now.year - 18, now.month, now.day);
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
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        )),
                  ),
                  Text('Select Date of Birth',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      )),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() => _dateOfBirth = newDate);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        )),
                  ),
                  Text('Select Weight',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      )),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _weight = selectedWeight;
                        _weightController.text = '$selectedWeight lbs';
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Done',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: selectedWeight - 50,
                ),
                itemExtent: 40,
                onSelectedItemChanged: (index) => selectedWeight = index + 50,
                children: List.generate(251, (index) {
                  final weight = index + 50;
                  return Center(
                    child: Text('$weight lbs',
                        style: context.textStyles.titleLarge?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchPlaces(String input, bool isDaytime) async {
    if (input.isEmpty) {
      setState(() {
        if (isDaytime) {
          _daytimeSuggestions = [];
        } else {
          _nighttimeSuggestions = [];
        }
      });
      return;
    }

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('googlePlacesAutocomplete').call({
        'input': input,
        'locationType': 'address',
      });

      final suggestions = (result.data['suggestions'] as List)
          .map((s) => Map<String, dynamic>.from(s))
          .toList();

      debugPrint('Received ${suggestions.length} suggestions');
      if (suggestions.isNotEmpty) {
        debugPrint('First suggestion: ${suggestions[0]}');
      }

      setState(() {
        if (isDaytime) {
          _daytimeSuggestions = suggestions;
        } else {
          _nighttimeSuggestions = suggestions;
        }
      });
    } catch (e) {
      debugPrint('Error fetching place suggestions: $e');
    }
  }

  void _selectPlace(Map<String, dynamic> suggestion, bool isDaytime) {
    final description = suggestion['description'] as String? ?? '';
    final lat = suggestion['lat'] as double?;
    final lng = suggestion['lng'] as double?;
    
    debugPrint('Selected place: $description with coordinates: lat=$lat, lng=$lng');
    
    setState(() {
      if (isDaytime) {
        _daytimeController.text = description;
        _daytimeAddress = description;
        _daytimeLat = lat;
        _daytimeLng = lng;
        _daytimeSuggestions = [];
        _daytimeFocus.unfocus();
      } else {
        _nighttimeController.text = description;
        _nighttimeAddress = description;
        _nighttimeLat = lat;
        _nighttimeLng = lng;
        _nighttimeSuggestions = [];
        _nighttimeFocus.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _daytimeController.dispose();
    _nighttimeController.dispose();
    _daytimeFocus.dispose();
    _nighttimeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1A1C1E) : const Color(0xFFFFF5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.pop(),
          ),
          title: const Text('Personal Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1C1E) : const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text('Personal Details',
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            )),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Date of Birth
              _buildSectionTitle('Date of Birth', isDark),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showDatePicker,
                child: _buildDetailCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date of Birth',
                  value: _dateOfBirth != null
                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                      : 'Select date of birth',
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),

              // Biological Sex
              _buildSectionTitle('Biological Sex', isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSexOption('male', Icons.male, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSexOption('female', Icons.female, isDark),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Weight
              _buildSectionTitle('Weight', isDark),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showWeightPicker,
                child: _buildDetailCard(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Weight',
                  value: _weight != null ? '$_weight lbs' : 'Select weight',
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),

              // Blood Type
              _buildSectionTitle('Blood Type', isDark),
              const SizedBox(height: 12),
              _buildBloodTypeGrid(isDark),
              const SizedBox(height: 20),

              // Daytime Address
              _buildSectionTitle('Daytime Address', isDark),
              const SizedBox(height: 12),
              _buildAddressField(
                icon: Icons.work_outline_rounded,
                label: 'Where are you during daytime?',
                controller: _daytimeController,
                focusNode: _daytimeFocus,
                suggestions: _daytimeSuggestions,
                isDark: isDark,
                onChanged: (value) {
                  _daytimeAddress = value;
                  _searchPlaces(value, true);
                },
                onSuggestionTap: (suggestion) => _selectPlace(suggestion, true),
              ),
              const SizedBox(height: 20),

              // Nighttime Address
              _buildSectionTitle('Nighttime Address', isDark),
              const SizedBox(height: 12),
              _buildAddressField(
                icon: Icons.home_outlined,
                label: 'Where are you at nighttime?',
                controller: _nighttimeController,
                focusNode: _nighttimeFocus,
                suggestions: _nighttimeSuggestions,
                isDark: isDark,
                onChanged: (value) {
                  _nighttimeAddress = value;
                  _searchPlaces(value, false);
                },
                onSuggestionTap: (suggestion) => _selectPlace(suggestion, false),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Save Changes',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title,
        style: context.textStyles.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ));
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isEditable = false,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
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
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: isEditable && controller != null
                ? TextField(
                    controller: controller,
                    style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: context.textStyles.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    onChanged: onChanged,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          )),
                      const SizedBox(height: 4),
                      Text(value,
                          style: context.textStyles.titleMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
          ),
          if (!isEditable)
            Icon(Icons.arrow_forward_ios,
                size: 16, color: isDark ? Colors.white38 : Colors.black38),
        ],
      ),
    );
  }

  Widget _buildSexOption(String sex, IconData icon, bool isDark) {
    final isSelected = _biologicalSex == sex;
    final displaySex = sex == 'male' ? 'Male' : 'Female';

    return GestureDetector(
      onTap: () => setState(() => _biologicalSex = sex),
      child: Container(
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
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white60 : Colors.black54),
                size: 32),
            const SizedBox(height: 8),
            Text(displaySex,
                style: context.textStyles.titleMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeGrid(bool isDark) {
    final bloodTypes = BloodType.values
        .map((e) => e == BloodType.unknown ? "I don't know" : e.displayName)
        .toList();

    return GridView.builder(
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
          onTap: () => setState(() => _bloodType = bloodType),
          child: Container(
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
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isIDontKnow
                      ? Icons.help_outline_rounded
                      : Icons.bloodtype_rounded,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white60 : Colors.black54),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(bloodType,
                    textAlign: TextAlign.center,
                    style: context.textStyles.titleMedium?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: isIDontKnow ? 12 : null,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<Map<String, dynamic>> suggestions,
    required bool isDark,
    required ValueChanged<String> onChanged,
    required Function(Map<String, dynamic>) onSuggestionTap,
  }) {
    return Column(
      children: [
        Container(
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
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: context.textStyles.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
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
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                final description = suggestion['description'] as String? ?? '';
                final mainText = suggestion['mainText'] as String? ?? '';
                final secondaryText = suggestion['secondaryText'] as String? ?? '';
                
                // Use description if mainText is empty
                final displayTitle = mainText.isNotEmpty ? mainText : description;
                
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    displayTitle,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: secondaryText.isNotEmpty
                      ? Text(
                          secondaryText,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        )
                      : null,
                  onTap: () => onSuggestionTap(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
