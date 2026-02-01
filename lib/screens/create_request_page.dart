import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/models/blood_request_model.dart';

/// Page for creating a new blood request
class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController();

  String? _selectedBloodGroup;
  BloodComponent? _selectedComponent;
  UrgencyLevel _selectedUrgency = UrgencyLevel.medium;
  DateTime? _requiredByDate;
  bool _isSubmitting = false;
  bool _bloodGroupError = false;
  bool _componentError = false;

  final List<String> _bloodGroups = BloodType.values
      .where((type) => type != BloodType.unknown)
      .map((type) => type.displayName)
      .toList();

  // Blood compatibility matrix
  static const Map<String, Map<String, dynamic>> _compatibilityMatrix = {
    'wholeBlood': {
      'O-': ['O-'],
      'O+': ['O+', 'O-'],
      'A-': ['A-', 'O-'],
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'AB-': ['AB-', 'A-', 'B-', 'O-'],
      'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
    },
    'redBloodCells': {
      'O-': ['O-'],
      'O+': ['O+', 'O-'],
      'A-': ['A-', 'O-'],
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'AB-': ['AB-', 'A-', 'B-', 'O-'],
      'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
    },
    'platelets': {
      'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
      'O+': ['O+', 'O-', 'A+', 'B+', 'AB+'],
      'A-': ['A-', 'O-', 'A+', 'O+', 'AB-', 'AB+'],
      'A+': ['A+', 'A-', 'O+', 'O-', 'B+', 'AB+'],
      'B-': ['B-', 'O-', 'B+', 'O+', 'AB-', 'AB+'],
      'B+': ['B+', 'B-', 'O+', 'O-', 'A+', 'AB+'],
      'AB-': ['AB-', 'A-', 'B-', 'O-', 'AB+'],
      'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
    },
    'plasma': {
      'O-': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
      'O+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
      'A-': ['AB-', 'AB+', 'A-', 'A+'],
      'A+': ['AB+', 'AB-', 'A+', 'A-'],
      'B-': ['AB-', 'AB+', 'B-', 'B+'],
      'B+': ['AB+', 'AB-', 'B+', 'B-'],
      'AB-': ['AB-'],
      'AB+': ['AB+', 'AB-'],
    },
    'cryoprecipitate': {
      'all': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
    },
  };

  /// Returns compatible blood groups based on patient blood group and component
  List<String> _getCompatibleBloodGroups(String patientBloodGroup, BloodComponent component) {
    String componentKey;
    switch (component) {
      case BloodComponent.wholeBlood:
        componentKey = 'wholeBlood';
        break;
      case BloodComponent.redBloodCells:
        componentKey = 'redBloodCells';
        break;
      case BloodComponent.platelets:
        componentKey = 'platelets';
        break;
      case BloodComponent.plasma:
        componentKey = 'plasma';
        break;
      case BloodComponent.cryoprecipitate:
        componentKey = 'cryoprecipitate';
        break;
    }

    final matrix = _compatibilityMatrix[componentKey];
    if (matrix == null) return [patientBloodGroup];

    // Special case for cryoprecipitate - can use any blood type
    if (componentKey == 'cryoprecipitate') {
      return matrix['all'] as List<String>;
    }

    // Get compatible blood groups for the patient's blood type
    final compatible = matrix[patientBloodGroup];
    if (compatible == null) return [patientBloodGroup];

    return List<String>.from(compatible as List);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      await showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          DateTime tempPickedDate = _requiredByDate ?? DateTime.now().add(const Duration(days: 1));
          return Container(
            height: 300,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _requiredByDate = tempPickedDate);
                          Navigator.pop(context);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempPickedDate,
                    minimumDate: DateTime.now(),
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) {
        setState(() => _requiredByDate = picked);
      }
    }
  }

  void _showBloodComponentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: AppSpacing.paddingMd,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Select Blood Component',
                    style: context.textStyles.headlineSmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: BloodComponent.values.map((component) {
                    final isSelected = _selectedComponent == component;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          component.displayName,
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedComponent = component;
                            _componentError = false;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBloodGroupPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: AppSpacing.paddingMd,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Select Blood Group',
                    style: context.textStyles.headlineSmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _bloodGroups.map((group) {
                    final isSelected = _selectedBloodGroup == group;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          group, 
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedBloodGroup = group;
                            _bloodGroupError = false;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    // Validate form fields
    final isFormValid = _formKey.currentState!.validate();
    
    // Check blood group and component selections
    setState(() {
      _bloodGroupError = _selectedBloodGroup == null;
      _componentError = _selectedComponent == null;
    });

    // Show error messages and stop if validation fails
    if (!isFormValid || _bloodGroupError || _componentError) {
      String errorMessage = 'Please fill in all required fields:';
      List<String> errors = [];
      if (_titleController.text.trim().isEmpty) errors.add('Request Title');
      if (_componentError) errors.add('Blood Component');
      if (_bloodGroupError) errors.add('Blood Group');
      if (_quantityController.text.trim().isEmpty || int.tryParse(_quantityController.text) == null) errors.add('Quantity');
      // Notes are now optional

      
      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage\n${errors.join(', ')}'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user document to retrieve providerId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) throw Exception('User document not found');

      final userData = UserModel.fromJson(userDoc.data()!);
      final providerId = userData.providerId;
      if (providerId == null) throw Exception('Provider ID not found');

      // Create new request document in subcollection
      final requestsCollection = FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('requests');

      final requestDoc = requestsCollection.doc();
      final now = DateTime.now();

      // Calculate compatible blood groups based on patient blood group and component
      final compatibleBloodGroups = _getCompatibleBloodGroups(_selectedBloodGroup!, _selectedComponent!);

      final request = BloodRequestModel(
        id: requestDoc.id,
        providerId: providerId,
        requestedBy: user.uid,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        bloodGroup: _selectedBloodGroup!,
        component: _selectedComponent!,
        urgency: _selectedUrgency,
        quantity: int.parse(_quantityController.text),
        status: RequestStatus.open,
        requiredBy: _requiredByDate,
        createdAt: now,
        updatedAt: now,
      );

      // Add request to Firestore with 'active' status field and compatible blood groups
      final requestData = request.toJson();
      requestData['active'] = true; // Mark request as active
      requestData['bloodGroup'] = compatibleBloodGroups; // Override with compatible blood groups list
      requestData['patientBloodGroup'] = _selectedBloodGroup!; // Store original patient blood group
      await requestDoc.set(requestData);

      // Update provider's activeRequests count
      await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(providerId)
          .update({'activeRequests': FieldValue.increment(1)});

      debugPrint('Request created successfully with ID: ${requestDoc.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request created successfully'),
            backgroundColor: Color(0xFF388E3C),
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error creating request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Blood Request'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.paddingMd,
            children: [
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Request Title',
                  hintText: 'e.g., Urgent Blood Needed for Surgery',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Blood Component picker
              InkWell(
                onTap: () => _showBloodComponentPicker(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Blood Component Required',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _componentError ? const Color(0xFFD32F2F) : (isDark ? Colors.white24 : Colors.black12),
                          width: _componentError ? 2 : 1,
                        )),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _componentError ? const Color(0xFFD32F2F) : (isDark ? Colors.white24 : Colors.black12),
                          width: _componentError ? 2 : 1,
                        )),
                    prefixIcon: Icon(Icons.science_outlined,
                        color: _componentError ? const Color(0xFFD32F2F) : null),
                    errorText: _componentError ? 'Please select a blood component' : null,
                  ),
                  child: Text(
                    _selectedComponent?.displayName ?? 'Select blood component',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: _selectedComponent != null ? null : (_componentError ? const Color(0xFFD32F2F) : Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Blood Group picker
              InkWell(
                onTap: () => _showBloodGroupPicker(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Patient Blood Group',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _bloodGroupError ? const Color(0xFFD32F2F) : (isDark ? Colors.white24 : Colors.black12),
                          width: _bloodGroupError ? 2 : 1,
                        )),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _bloodGroupError ? const Color(0xFFD32F2F) : (isDark ? Colors.white24 : Colors.black12),
                          width: _bloodGroupError ? 2 : 1,
                        )),
                    prefixIcon: Icon(Icons.water_drop,
                        color: _bloodGroupError ? const Color(0xFFD32F2F) : null),
                    errorText: _bloodGroupError ? 'Please select a blood group' : null,
                  ),
                  child: Text(
                    _selectedBloodGroup ?? 'Select blood group',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: _selectedBloodGroup != null ? null : (_bloodGroupError ? const Color(0xFFD32F2F) : Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quantity field
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (Units)',
                  hintText: 'Number of blood units needed',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Urgency level
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.priority_high,
                            color: _getUrgencyColor(_selectedUrgency)),
                        const SizedBox(width: 8),
                        Text('Urgency Level',
                            style: context.textStyles.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: UrgencyLevel.values.map((urgency) {
                        final isSelected = _selectedUrgency == urgency;
                        return ChoiceChip(
                          label: Text(urgency.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected)
                              setState(() => _selectedUrgency = urgency);
                          },
                          selectedColor:
                              _getUrgencyColor(urgency).withValues(alpha: 0.3),
                          labelStyle: TextStyle(
                            color:
                                isSelected ? _getUrgencyColor(urgency) : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Required by date
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Required By (Optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _requiredByDate != null
                        ? '${_requiredByDate!.day}/${_requiredByDate!.month}/${_requiredByDate!.year}'
                        : 'Select date',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: _requiredByDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),



              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  alignLabelWithHint: true,
                  hintText: 'Any additional information about the request',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 84.0), // Align icon with top of 4 lines
                    child: const Icon(Icons.notes),
                  ),
                ),
                maxLines: 4,
                 // No validator needed for optional field
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          'Create Request',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUrgencyColor(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.critical:
        return const Color(0xFFD32F2F);
      case UrgencyLevel.high:
        return const Color(0xFFF57C00);
      case UrgencyLevel.medium:
        return const Color(0xFFF9A825); // Yellow 800 - more visible
      case UrgencyLevel.low:
        return const Color(0xFF388E3C);
    }
  }
}
