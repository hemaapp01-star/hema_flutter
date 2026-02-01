import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/nav.dart';
import 'package:hema/services/gemini_service.dart';
import 'package:hema/services/donor_geospatial_service.dart';
import 'package:hema/services/firebase_messaging_service.dart';
import 'package:hema/services/adk_agent_service.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/models/message_model.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/models/healthcare_provider_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:convert';
import 'dart:math' as math;

/// Donor home page with command center features
class DonorHomePage extends StatefulWidget {
  const DonorHomePage({super.key});

  @override
  State<DonorHomePage> createState() => _DonorHomePageState();
}

class _DonorHomePageState extends State<DonorHomePage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: const DonorDashboardTab(),
    ),
    const RequestsChatTab(),
    const DonorProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Check if user has completed onboarding, redirect if not
  Future<void> _checkOnboardingStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in, redirecting to welcome');
        if (mounted) context.go(AppRoutes.welcome);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint(
            'User document not found, redirecting to user type selection');
        if (mounted) context.go(AppRoutes.userTypeSelection);
        return;
      }

      final userData = UserModel.fromJson(userDoc.data()!);

      if (!userData.onboarded) {
        debugPrint(
            'User has not completed onboarding, redirecting to donor consent');
        if (mounted) context.go(AppRoutes.donorConsent);
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_rounded),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Dashboard tab - The Command Center
class DonorDashboardTab extends StatefulWidget {
  const DonorDashboardTab({super.key});

  @override
  State<DonorDashboardTab> createState() => _DonorDashboardTabState();
}

class _DonorDashboardTabState extends State<DonorDashboardTab> {
  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  // User data - loaded from Firestore
  String _userName = "Donor";
  String _bloodType = "O+";
  BloodType? _bloodTypeEnum; // Store the actual enum to check for unknown
  int _livesSaved = 0;

  final DonorGeospatialService _donorService = DonorGeospatialService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data and availability status from Firestore
  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // Calculate lives saved (typically 3 lives per donation)
          final totalDonations = data['totalDonations'] as int? ?? 0;
          final livesSaved = totalDonations * 3;

          // Parse blood type from enum to display format
          String bloodTypeDisplay = 'O+';
          BloodType? bloodTypeEnum;
          debugPrint('Raw blood type from Firebase: ${data['bloodType']}');
          if (data['bloodType'] != null) {
            try {
              bloodTypeEnum = BloodType.fromJson(data['bloodType'] as String);
              bloodTypeDisplay = bloodTypeEnum.displayName;
              debugPrint(
                  'Parsed blood type enum: $bloodTypeEnum, display: $bloodTypeDisplay');
            } catch (e) {
              debugPrint('Error parsing blood type: $e');
            }
          } else {
            debugPrint('Blood type is null in Firebase data');
          }

          setState(() {
            _userName = data['firstName'] as String? ?? 'Donor';
            _bloodType = bloodTypeDisplay;
            _bloodTypeEnum = bloodTypeEnum;
            _isAvailable = data['isAvailable'] as bool? ?? false;
            _livesSaved = livesSaved;
            _isLoading = false;
          });
          debugPrint(
              'Final state - bloodTypeEnum: $_bloodTypeEnum, isUnknown: ${_bloodTypeEnum == BloodType.unknown}');
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Check and request notification permissions
  Future<bool> _checkNotificationPermissions() async {
    try {
      final settings = await _messaging.getNotificationSettings();

      // Check if notifications are authorized
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Already authorized, ensure token is saved
        await FirebaseMessagingService.requestPermissionAndSetupToken();
        return true;
      }

      // If not determined yet, request permission
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Use FirebaseMessagingService to request permission and setup token
        final granted = await FirebaseMessagingService.requestPermissionAndSetupToken();

        if (!granted && mounted) {
          // User denied the permission request
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notifications Required'),
              content: const Text(
                'To receive alerts when there is a need for blood near you, please enable notifications.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        return granted;
      }

      // If denied (user previously denied or iOS permanently denied), show dialog with app settings option
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notifications Required'),
              content: const Text(
                'To receive alerts when there is a need for blood near you, please enable notifications in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            // Open app settings using app_settings package
            await AppSettings.openAppSettings(
                type: AppSettingsType.notification);
          }
        }
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  /// Toggle availability and sync across user and donor collections
  Future<void> _toggleAvailability(bool value) async {
    if (_isUpdating) return; // Prevent multiple simultaneous updates

    // Only check permissions when turning availability ON
    if (value) {
      // Check current notification permission status
      final settings = await _messaging.getNotificationSettings();

      // If notifications are denied or not determined, request permission
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        final hasPermission = await _checkNotificationPermissions();
        if (!hasPermission) {
          // Don't toggle if permissions not granted
          return;
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Already authorized, ensure token is refreshed/saved
        await FirebaseMessagingService.requestPermissionAndSetupToken();
      } else {
        // For any other status (e.g., permanently denied), don't allow toggle
        return;
      }
    }

    setState(() => _isUpdating = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Update availability in both collections using batch write
      final batch = _firestore.batch();

      // Update user collection
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'isAvailable': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update both donor documents (daytime and nighttime)
      batch.update(
        _firestore.collection('donors').doc('${userId}_daytime'),
        {'isAvailable': value},
      );
      batch.update(
        _firestore.collection('donors').doc('${userId}_nighttime'),
        {'isAvailable': value},
      );

      await batch.commit();

      setState(() {
        _isAvailable = value;
        _isUpdating = false;
      });

      debugPrint(
          'Successfully updated availability to $value across all collections');
    } catch (e) {
      debugPrint('Error toggling availability: $e');
      setState(() => _isUpdating = false);

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update availability: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Color(0xFF1A1C1E), Color(0xFF2D1B1B)]
              : [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header with name and blood type badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome,',
                        style: context.textStyles.bodyLarge?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName,
                        style: context.textStyles.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  // Only show blood type badge if not unknown
                  if (_bloodTypeEnum != null &&
                      _bloodTypeEnum != BloodType.unknown)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE12E1F),
                      ),
                      child: Center(
                        child: Text(
                          _bloodType,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Color(0xFFFFFFFF)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Readiness Toggle - The Hero Element
              AvailabilityToggleCard(
                isAvailable: _isAvailable,
                isLoading: _isLoading,
                isUpdating: _isUpdating,
                onToggle: _toggleAvailability,
              ),
              const SizedBox(height: 24),

              // Impact Stats
              ImpactStatsCard(livesSaved: _livesSaved),
              const SizedBox(height: 24),

              // Preparation Checklist
              const PreparationChecklistCard(),
              const SizedBox(height: 24),

              // Quick Tips Section
              const QuickTipsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Availability toggle card - The hero element
class AvailabilityToggleCard extends StatelessWidget {
  final bool isAvailable;
  final bool isLoading;
  final bool isUpdating;
  final ValueChanged<bool> onToggle;

  const AvailabilityToggleCard({
    super.key,
    required this.isAvailable,
    this.isLoading = false,
    this.isUpdating = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAvailable
              ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
              : [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAvailable ? Colors.green : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability Status',
                      style: context.textStyles.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAvailable
                          ? 'Ready to Save Lives'
                          : 'Currently Unavailable',
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading || isUpdating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Transform.scale(
                    scale: 1.2,
                    child: Switch(
                      value: isAvailable,
                      onChanged: onToggle,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAvailable
                        ? 'You will appear in provider searches'
                        : 'Toggle on when you are available to donate',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
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
}

/// Impact stats card
class ImpactStatsCard extends StatelessWidget {
  final int livesSaved;

  const ImpactStatsCard({super.key, required this.livesSaved});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donations Made',
                  style: context.textStyles.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$livesSaved',
                      style: context.textStyles.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'and counting...',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Preparation checklist card
class PreparationChecklistCard extends StatelessWidget {
  const PreparationChecklistCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Pre-Donation Checklist',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ChecklistItem(
            icon: Icons.water_drop,
            text: 'Drink 3 glasses of water (2 hours)',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ChecklistItem(
            icon: Icons.restaurant,
            text: 'Eat an iron-rich meal',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ChecklistItem(
            icon: Icons.badge_outlined,
            text: 'Bring your ID',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// Checklist item widget
class ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const ChecklistItem({
    super.key,
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.87)
                  : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick tips grid
class QuickTipsGrid extends StatelessWidget {
  const QuickTipsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickTipCard(
            icon: Icons.school_outlined,
            title: 'Learn',
            subtitle: 'Donation process',
            color: Colors.blue,
            onTap: () => context.push(AppRoutes.donationInfo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickTipCard(
            icon: Icons.military_tech_outlined,
            title: 'Rewards',
            subtitle: 'Hero badges',
            color: Colors.amber,
            onTap: () => context.push(AppRoutes.rewards),
          ),
        ),
      ],
    );
  }
}

/// Quick tip card
class QuickTipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const QuickTipCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.textStyles.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Requests chat tab - Chat interface with Hema
class RequestsChatTab extends StatefulWidget {
  const RequestsChatTab({super.key});

  @override
  State<RequestsChatTab> createState() => _RequestsChatTabState();
}

class _RequestsChatTabState extends State<RequestsChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasAgreed = false;
  String? _hospitalAddress;
  bool _isActiveRequest = false;
  bool _isInitializingSession = false;
  bool _isRequestActive = true; // Assume active until validated

  // Mock request data
  final String _hospital = 'Peace Care Hospital';
  final String _bloodType = 'O+';
  final String _distance = '5 minutes';
  final int _units = 2;

  @override
  void initState() {
    super.initState();
    _loadActiveRequestStatus();
    _loadMessageHistory(); // Load messages immediately (cache + Firestore)
    _initializeSession(); // Initialize session in background
    _listenToActiveRequestStatus();
  }

  /// Load user's active request status from Firestore
  Future<void> _loadActiveRequestStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (mounted) {
          setState(() {
            _isActiveRequest = data?['activeRequest'] as bool? ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading active request status: $e');
    }
  }

  /// Listen to changes in active request status
  void _listenToActiveRequestStatus() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        final newActiveRequest = data?['activeRequest'] as bool? ?? false;
        if (_isActiveRequest != newActiveRequest) {
          setState(() {
            _isActiveRequest = newActiveRequest;
          });
          debugPrint('✅ Active request status updated to: $newActiveRequest');
        }
      }
    });
  }

  /// Initialize Hema Agent session in background
  /// This creates the session once so conversation history is preserved
  Future<void> _initializeSession() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      setState(() => _isInitializingSession = true);

      // First, validate that the request is still active
      final isActive = await _validateRequestStatus();
      
      if (!isActive) {
        debugPrint('⚠️ Request is no longer active, skipping session creation');
        if (mounted) {
          setState(() {
            _isRequestActive = false;
            _isInitializingSession = false;
          });
        }
        return;
      }

      // Initialize session (lightweight, just creates session object)
      final success = await AdkAgentService.createSession(
        userId: userId,
        sessionId: userId,
      );

      if (mounted) {
        setState(() {
          _isRequestActive = true;
          _isInitializingSession = false;
        });
      }

      if (success) {
        debugPrint('✅ Session initialized for user: $userId');
      } else {
        debugPrint('⚠️ Session initialization failed, will retry on first message');
      }
    } catch (e) {
      debugPrint('❌ Error initializing session: $e');
      if (mounted) setState(() => _isInitializingSession = false);
    }
  }

  /// Validate that the blood request is still active
  Future<bool> _validateRequestStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;

      // Find the last request message to get request ID and provider ID
      if (_messages.isEmpty) {
        debugPrint('ℹ️ No messages loaded yet, assuming request is active for now');
        return true;
      }

      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == MessageRole.request && _messages[i].requestData != null) {
          final requestData = _messages[i].requestData!;
          
          // Try both nested and flat structures
          final requestId = requestData['bloodRequest']?['id'] as String? ?? requestData['id'] as String?;
          final providerId = requestData['providerLocation']?['id'] as String? ?? requestData['providerId'] as String?;

          if (requestId == null || providerId == null) {
            debugPrint('⚠️ Missing request ID or provider ID in request data: $requestData');
            // If we can't find IDs, don't disable chat yet - might be a legacy format
            return true; 
          }

          debugPrint('🔍 Validating request: $requestId from provider: $providerId');

          // Check if request exists and is active
          // Try all possible path variations (plural/singular)
          DocumentSnapshot? requestDoc;
          final List<String> collectionPaths = [
            'healthcare_providers/$providerId/requests/$requestId',
            'healthcare_providers/$providerId/request/$requestId',
            'healthcare_provider/$providerId/requests/$requestId',
            'healthcare_provider/$providerId/request/$requestId',
          ];

          for (final path in collectionPaths) {
            final doc = await FirebaseFirestore.instance.doc(path).get();
            if (doc.exists) {
              requestDoc = doc;
              debugPrint('✅ Found request at path: $path');
              break;
            }
          }

          if (requestDoc == null || !requestDoc.exists) {
            debugPrint('❌ Request $requestId not found in any known collection path');
            return false;
          }

          final data = requestDoc.data() as Map<String, dynamic>;
          debugPrint('📄 Request data: $data');
          
          // Prioritizing "active" as confirmed by the user, with fallbacks for safety
          final bool isActive = data['active'] as bool? ?? 
                               data['isActive'] as bool? ?? 
                               (data['status'] == 'open');
          
          debugPrint('📊 Validation result: isActive=$isActive (prioritized field "active": ${data['active']})');
          return isActive;
        }
      }

      debugPrint('ℹ️ No request message found in chat history, assuming active');
      return true;
    } catch (e) {
      debugPrint('❌ Error validating request status: $e');
      return true; // Don't block chat on errors
    }
  }


  /// Load message history from cache first, then from Firestore
  Future<void> _loadMessageHistory() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      debugPrint('📥 Loading message history for user: $userId');

      // Load from cache first for instant display
      await _loadMessagesFromCache(userId);

      // Then fetch from Firestore in the background
      debugPrint('🔥 Fetching messages from Firestore: users/$userId/messages');
      
      // Try getting all documents first to debug
      final allDocsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .get();
          
      debugPrint('📊 Total documents in messages collection: ${allDocsSnapshot.docs.length}');
      if (allDocsSnapshot.docs.isNotEmpty) {
        for (var doc in allDocsSnapshot.docs) {
          debugPrint('📄 Doc ID: ${doc.id}, Data keys: ${doc.data().keys.toList()}');
          final data = doc.data();
          if (data['date'] == null && data['timeStamp'] == null && data['timestamp'] == null) {
            debugPrint('⚠️ WARNING: Document ${doc.id} is missing "date", "timeStamp", and "timestamp" fields');
          }
        }
      }

      // Fetch all messages without ordering first (to handle mixed schema)
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .get();

      debugPrint('📉 Total documents retrieved: ${messagesSnapshot.docs.length}');

      if (!mounted) return;

      final messages = messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        final messageModel = MessageModel.fromJson(data, doc.id);

        // Handle request messages differently
        if (messageModel.role == MessageRole.request) {
          // Parse request data from content
          Map<String, dynamic>? requestData;
          try {
            requestData =
                jsonDecode(messageModel.content) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('Error parsing request data: $e');
          }

          return ChatMessage(
            text: messageModel.content,
            isUser: false,
            timestamp: messageModel.date,
            role: MessageRole.request,
            requestData: requestData,
          );
        }

        // Check if it's a provider message
        if (messageModel.isProvider) {
          debugPrint(
              '📨 Provider message - roleString: "${messageModel.roleString}", providerId: "${messageModel.providerId}", content: "${messageModel.content}"');

          // Get requestId from the message data if available
          String? requestId;
          try {
            requestId = data['requestId'] as String?;
          } catch (e) {
            debugPrint('Error getting requestId from message: $e');
          }

          return ChatMessage(
            text: messageModel.content,
            isUser: false,
            timestamp: messageModel.date,
            providerId: messageModel.providerId,
            requestId: requestId,
          );
        }

        return ChatMessage(
          text: messageModel.content,
          isUser: messageModel.role == MessageRole.user,
          timestamp: messageModel.date,
          role: messageModel.role,
        );
      }).toList();

      // Sort messages by date
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });

      // Save to cache for next time
      await _saveMessagesToCache(userId, messages);

      _scrollToBottom();
      
      // Initialize session after loading messages to ensure validation context exists
      _initializeSession();
    } catch (e) {
      debugPrint('❌ Error loading message history: $e');
    }
  }

  /// Load messages from local cache
  Future<void> _loadMessagesFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('messages_$userId');

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final cachedMessages = decoded.map((item) {
          final providerId = item['providerId'] as String?;
          final roleStr = item['role'] as String?;
          MessageRole? role;
          if (roleStr != null) {
            role = MessageRole.fromJson(roleStr);
          }

          return ChatMessage(
            text: item['text'] as String,
            isUser: item['isUser'] as bool,
            timestamp: DateTime.parse(item['timestamp'] as String),
            role: role,
            providerId: providerId,
            requestId: item['requestId'] as String?,
            requestData: item['requestData'] as Map<String, dynamic>?,
          );
        }).toList();

        if (!mounted) return;

        setState(() {
          _messages.clear();
          _messages.addAll(cachedMessages);
        });

         _scrollToBottom();
         debugPrint('✅ Loaded ${cachedMessages.length} messages from cache');
         
         // Initialize session after loading from cache for fast start
         _initializeSession();
       }
     } catch (e) {
      debugPrint('⚠️ Error loading messages from cache: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Save messages to local cache
  Future<void> _saveMessagesToCache(
      String userId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        messages
            .map((msg) => {
                  'text': msg.text,
                  'isUser': msg.isUser,
                  'timestamp': msg.timestamp.toIso8601String(),
                  'role': msg.role?.toJson(),
                  'providerId': msg.providerId,
                  'requestId': msg.requestId,
                  'requestData': msg.requestData,
                })
            .toList(),
      );
      await prefs.setString('messages_$userId', encoded);
      debugPrint('✅ Saved ${messages.length} messages to cache');
    } catch (e) {
      debugPrint('⚠️ Error saving messages to cache: $e');
    }
  }

  /// Save message to Firestore messages subcollection
  Future<void> _saveMessageToFirestore({
    required String userId,
    required String content,
    required MessageRole role,
  }) async {
    try {
      final messageModel = MessageModel(
        id: '', // Firestore will generate the ID
        content: content,
        role: role,
        date: DateTime.now(),
      );

      // Save to users/{userId}/messages subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .add(messageModel.toJson());

      debugPrint('✅ Message saved to Firestore: ${role.name}');
    } catch (e) {
      debugPrint('❌ Error saving message to Firestore: $e');
    }
  }

  /// Save donor message to Firestore when conversation is with a provider
  Future<void> _saveMessageToFirestoreWithProvider({
    required String userId,
    required String content,
    required String providerId,
  }) async {
    try {
      final now = DateTime.now();

      // Find the requestId from the last provider message
      String? requestId;
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].isProvider && _messages[i].requestId != null) {
          requestId = _messages[i].requestId;
          break;
        }
      }

      if (requestId == null) {
        debugPrint('❌ No requestId found in provider messages');
        throw Exception('Cannot send message: requestId not found');
      }

      final messageData = {
        'content': content,
        'role': 'user',
        'date': Timestamp.fromDate(now),
        'providerId': providerId,
        'requestId': requestId,
      };

      // 1. Add message to donor's messages subcollection
      final donorMessageRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .add(messageData);

      debugPrint(
          '✅ Donor message added to users/$userId/messages: ${donorMessageRef.id}');

      // 2. Add message to provider's conversation path
      // Path: healthcare_providers/{providerId}/conversations/{requestId}/donors/{donorId}/messages/{messageId}
      await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(providerId)
          .collection('conversations')
          .doc(requestId)
          .collection('donors')
          .doc(userId)
          .collection('messages')
          .doc(donorMessageRef.id)
          .set(messageData);

      debugPrint(
          '✅ Donor message saved to provider conversation: healthcare_providers/$providerId/conversations/$requestId/donors/$userId/messages/${donorMessageRef.id}');
    } catch (e) {
      debugPrint('❌ Error saving donor message with provider: $e');
      rethrow;
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check if user is in active request
    if (!_isActiveRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You can only send messages when you are in an active donation request',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      // Get user ID
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Check if conversation has been handed over to a provider
      // Look for the last non-user message to see if it's from a provider
      ChatMessage? lastProviderMessage;
      for (int i = _messages.length - 2; i >= 0; i--) {
        if (!_messages[i].isUser && _messages[i].isProvider) {
          lastProviderMessage = _messages[i];
          break;
        }
      }

      // If conversation is with a provider, save to Firestore directly
      if (lastProviderMessage != null &&
          lastProviderMessage.providerId != null) {
        debugPrint(
            '🔄 Conversation handed over to provider: ${lastProviderMessage.providerId}');

        // Save user message to Firestore with providerId and requestId
        await _saveMessageToFirestoreWithProvider(
          userId: userId,
          content: text,
          providerId: lastProviderMessage.providerId!,
        );

        setState(() {
          _isLoading = false;
        });

        // Update cache with new messages
        await _saveMessagesToCache(userId, _messages);

        _scrollToBottom();
        return;
      }

      // Otherwise, continue with Hema Agent
      debugPrint('💬 Sending message to Hema Agent');

      // Extract context from the last request message
      Map<String, dynamic>? context;
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == MessageRole.request && _messages[i].requestData != null) {
          context = _messages[i].requestData;
          debugPrint('📦 Extracted context from request message');
          break;
        }
      }

      // Save user message to Firestore
      await _saveMessageToFirestore(
        userId: userId,
        content: text,
        role: MessageRole.user,
      );

      // Send message to Hema Agent with context
      final response = await AdkAgentService.sendMessage(
        userId: userId,
        sessionId: userId,
        message: text,
        context: context,
      );

      final aiMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      // Save agent response to Firestore
      await _saveMessageToFirestore(
        userId: userId,
        content: response,
        role: MessageRole.hema,
      );

      if (text.toLowerCase().contains('yes') ||
          text.toLowerCase().contains('available') ||
          text.toLowerCase().contains('can donate') ||
          text.toLowerCase().contains('i\'ll go') ||
          text.toLowerCase().contains('on my way')) {
        if (response.toLowerCase().contains('address') ||
            response.toLowerCase().contains('123') ||
            response.toLowerCase().contains('peace care')) {
          setState(() {
            _hasAgreed = true;
            _hospitalAddress = '123 Peace Care Drive, Medical District';
          });
        }
      }

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      // Update cache with new messages
      await _saveMessagesToCache(userId, _messages);

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error getting response from Hema: $e');

      final errorMessage = ChatMessage(
        text:
            'Sorry, I\'m having trouble connecting right now. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1C1E), const Color(0xFF2D1B1B)]
              : [const Color(0xFFFFF5F5), const Color(0xFFFFEBEE)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Chat header
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/hema_logo_2_1.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hema',
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Donation Agent',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: AppSpacing.paddingMd,
                itemCount: _messages.length +
                    (_isLoading ? 1 : 0) +
                    (_hasAgreed && _hospitalAddress != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_hasAgreed &&
                      _hospitalAddress != null &&
                      index == _messages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: HospitalAddressCard(
                        hospitalName: _hospital,
                        address: _hospitalAddress!,
                        distance: _distance,
                      ),
                    );
                  }

                  if (index ==
                      _messages.length +
                          (_hasAgreed && _hospitalAddress != null ? 1 : 0)) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: TypingIndicator(),
                    );
                  }

                  final adjustedIndex = index;
                  final message = _messages[adjustedIndex];

                  // Display request card for request messages
                  if (message.role == MessageRole.request &&
                      message.requestData != null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child:
                          BloodRequestCard(requestData: message.requestData!),
                    );
                  }

                  return ChatBubble(message: message);
                },
              ),
            ),

            // Message input
            Opacity(
              opacity: (_isActiveRequest && _isRequestActive) ? 1.0 : 0.5,
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: _isActiveRequest && _isRequestActive,
                        decoration: InputDecoration(
                          hintText: !_isActiveRequest
                              ? 'Not in active request...'
                              : !_isRequestActive
                                  ? 'This request is no longer active'
                                  : 'Type your message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[850] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isActiveRequest
                              ? [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.8),
                                ]
                              : [
                                  Colors.grey,
                                  Colors.grey.withValues(alpha: 0.8),
                                ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon:
                            const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: _isActiveRequest
                            ? () => _sendMessage(_messageController.text)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageRole? role;
  final String? providerId; // For provider messages
  final String? requestId; // For messages in provider conversations
  final Map<String, dynamic>? requestData; // For role:request messages

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    MessageRole? role,
    this.providerId,
    this.requestId,
    this.requestData,
  }) : role = role ?? (isUser ? MessageRole.user : MessageRole.hema);

  bool get isProvider => providerId != null;
}

/// Chat bubble widget
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // For provider messages, fetch and display hospital name
    if (message.isProvider) {
      return FutureBuilder<String>(
        future: _fetchProviderName(message.providerId!),
        builder: (context, snapshot) {
          final hospitalName = snapshot.data ?? 'Healthcare Provider';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green, width: 1),
                      borderRadius: BorderRadius.circular(20).copyWith(
                        topLeft: const Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: () {
                            debugPrint(
                                '🔍 STARTING Provider lookup - providerId: "${message.providerId}", isProvider: ${message.isProvider}, fullRole: ${message.text}');
                            return FirebaseFirestore.instance
                                .collection('healthcare_providers')
                                .doc(message.providerId!)
                                .get();
                          }(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              debugPrint('⏳ Provider lookup waiting...');
                              return const SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                            if (snapshot.hasError ||
                                !snapshot.hasData ||
                                !snapshot.data!.exists) {
                              debugPrint(
                                  '❌ Provider lookup FAILED - providerId: "${message.providerId}", Error: ${snapshot.error}, hasData: ${snapshot.hasData}, exists: ${snapshot.hasData ? snapshot.data!.exists : false}');
                              return Text('Healthcare Provider',
                                  style:
                                      context.textStyles.labelMedium?.copyWith(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ));
                            }
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            debugPrint('✅ Provider data retrieved: $data');
                            final hospitalName =
                                data?['organizationName'] as String? ??
                                    'Healthcare Provider';
                            debugPrint(
                                '🏥 Final hospital name: "$hospitalName"');
                            return Text(
                              hospitalName,
                              style: context.textStyles.labelMedium?.copyWith(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.text,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Image.asset(
              'assets/images/hema_logo_2_1.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(20).copyWith(
                  topLeft: message.isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  topRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: message.isUser
                      ? Colors.white
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black87),
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 40),
          if (!message.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Future<String> _fetchProviderName(String providerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(providerId)
          .get();

      if (doc.exists) {
        return doc.data()?['organizationName'] as String? ??
            'Healthcare Provider';
      }
    } catch (e) {
      debugPrint('Error fetching provider name: $e');
    }
    return 'Healthcare Provider';
  }
}

/// Typing indicator for when Hema is responding
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/hema_logo_2_1.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.favorite,
            color: Colors.red,
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(20).copyWith(
              topLeft: const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BouncingDot(delay: 0),
              const SizedBox(width: 4),
              _BouncingDot(delay: 200),
              const SizedBox(width: 4),
              _BouncingDot(delay: 400),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bouncing dot animation for typing indicator
class _BouncingDot extends StatefulWidget {
  final int delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isDark ? Colors.white54 : Colors.black54,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Hospital address card shown when donor agrees to donate
class HospitalAddressCard extends StatelessWidget {
  final String hospitalName;
  final String address;
  final String distance;

  const HospitalAddressCard({
    super.key,
    required this.hospitalName,
    required this.address,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hospitalName,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.87)
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$distance away',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.87)
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Open maps or navigation
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.navigation, size: 20),
              label: Text(
                'Get Directions',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blood request card displayed in chat for role:request messages
class BloodRequestCard extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const BloodRequestCard({super.key, required this.requestData});

  @override
  State<BloodRequestCard> createState() => _BloodRequestCardState();
}

class _BloodRequestCardState extends State<BloodRequestCard> {
  bool _isAccepting = false;
  String? _doctorName;
  bool _hasAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadRequestingDoctor();
    _checkIfAccepted();
  }

  Future<void> _checkIfAccepted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          final activeRequest =
              userDoc.data()?['activeRequest'] as bool? ?? false;
          if (activeRequest) {
            setState(() => _hasAccepted = true);
          }
        }
      } catch (e) {
        debugPrint('Error checking user acceptance status: $e');
      }
    }
  }

  Future<void> _loadRequestingDoctor() async {
    final bloodRequest =
        widget.requestData['bloodRequest'] as Map<String, dynamic>?;
    if (bloodRequest == null) {
        debugPrint('❌ _loadRequestingDoctor: bloodRequest is null');
        return;
    }

    final requestedBy = bloodRequest['requestedBy'] as String?;
    debugPrint('🔍 _loadRequestingDoctor: requestedBy ID = $requestedBy');
    
    if (requestedBy != null && requestedBy.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(requestedBy)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data();
          debugPrint('✅ _loadRequestingDoctor: Found user doc. Data: $data');
          if (data != null) {
            final firstName = data['firstName'] as String? ?? '';
            final surname = data['surname'] as String? ?? ''; // or lastName
            setState(() {
              _doctorName = '$firstName $surname'.trim();
            });
            debugPrint('👨‍⚕️ _loadRequestingDoctor: Set doctor name to "$_doctorName"');
          }
        } else {
            debugPrint('⚠️ _loadRequestingDoctor: User doc does not exist or not mounted');
        }
      } catch (e) {
        debugPrint('Error loading doctor name: $e');
      }
    } else {
        debugPrint('⚠️ _loadRequestingDoctor: requestedBy field is missing or empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse request data
    final bloodRequest =
        widget.requestData['bloodRequest'] as Map<String, dynamic>?;
    final providerLocation =
        widget.requestData['providerLocation'] as Map<String, dynamic>?;

    if (bloodRequest == null) {
      return const SizedBox.shrink();
    }

    // Extract key fields with safe parsing
    final title = bloodRequest['title']?.toString() ?? 'Blood Request';
    
    final orgNameRaw =
        widget.requestData['providerLocation']?['organizationName'] ??
        widget.requestData['providerLocation']?['organisationName'] ??
        bloodRequest['organisationName'];
    final organisationName = orgNameRaw?.toString() ?? 'Medical Facility';
    
    final componentRaw = bloodRequest['component'];
    final component = componentRaw is List 
        ? (componentRaw.isNotEmpty ? componentRaw.first.toString() : 'wholeBlood')
        : componentRaw?.toString() ?? 'wholeBlood';
        
    final urgencyRaw = bloodRequest['urgency'];
    final urgency = urgencyRaw?.toString() ?? 'medium';
    
    final bloodGroupRaw = bloodRequest['bloodGroup'];
    final bloodGroup = bloodGroupRaw is List 
        ? bloodGroupRaw.join(', ') 
        : bloodGroupRaw?.toString() ?? '';
        
    final quantity = int.tryParse(bloodRequest['quantity'].toString()) ?? 0;
    final address = providerLocation?['address']?.toString() ?? '';
    final matchedDonors = bloodRequest['matchedDonors'] as List? ?? [];
    final matchedCount = matchedDonors.length;
    final requestId = bloodRequest['id'] as String?;
    final providerId = bloodRequest['providerId'] as String?;

    // Get component display name
    String componentDisplay = 'Whole Blood';
    try {
      componentDisplay = BloodComponent.fromJson(component).displayName;
    } catch (e) {
      debugPrint('Error parsing component: $e');
    }

    // Get urgency color and display name
    Color urgencyColor = const Color(0xFFF9A825); // Default Medium
    String urgencyDisplay = 'Medium';
    try {
      final urgencyLevel = UrgencyLevel.fromJson(urgency);
      urgencyDisplay = urgencyLevel.displayName;
      switch (urgencyLevel) {
        case UrgencyLevel.critical:
          urgencyColor = const Color(0xFFD32F2F);
          break;
        case UrgencyLevel.high:
          urgencyColor = const Color(0xFFF57C00);
          break;
        case UrgencyLevel.medium:
          urgencyColor = const Color(0xFFF9A825);
          break;
        case UrgencyLevel.low:
          urgencyColor = const Color(0xFF388E3C);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing urgency: $e');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE57373),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with request title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request',
                      style: context.textStyles.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      title,
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Doctor name if available
          if (_doctorName != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Requested by Dr. $_doctorName',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Request details (Urgency only)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.grey[850] : Colors.white)
                  ?.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 24), // Wider padding for center look
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgencyColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.priority_high,
                        color: urgencyColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      urgencyDisplay,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Address if available
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Accept Request Button
          if (!_hasAccepted) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAccepting
                    ? null
                    : () => _handleAcceptRequest(requestId, providerId),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF4CAF50), // Green for both modes
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: _isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isAccepting ? 'Connecting...' : 'Chat With Hema',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Handle accepting the blood request
  Future<void> _handleAcceptRequest(
      String? requestId, String? providerId) async {
    if (requestId == null || providerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to accept request: Missing information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Optimistically hide button immediately or show loading? 
    // User said "no need for loading State". 
    // We'll show a quick loading then hide.
    setState(() => _isAccepting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userId = user.uid;

      debugPrint('🏥 Initiating chat for request: $requestId');

      // Initialize session for this user
      await AdkAgentService.createSession(
        userId: userId,
        sessionId: userId,
      );

      // Update user status - this triggers the chat flow with Hema
      // Note: We NO LONGER add the user to matchedDonors here.
      // That is now handled by the agent after confirmation.
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'activeRequest': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User status updated to activeRequest: true. Chat initiated.');

      // 3. Send initial message from Hema to start conversation
      final welcomeMessage =
          'Thank you for accepting this blood donation request! I\'m here to help you through the process. '
          'Let me ask you a few quick questions to make sure you\'re ready to donate today.\n\n'
          'Have you donated blood in the last 8 weeks?';

      final messageModel = MessageModel(
        id: '',
        content: welcomeMessage,
        role: MessageRole.hema,
        date: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .add(messageModel.toJson());

      if (mounted) {
        setState(() {
          _hasAccepted = true;
          _isAccepting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Request accepted! Hema will guide you through the next steps.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error accepting request: $e');
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Small info item for request card
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.textStyles.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textStyles.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Donor profile tab
class DonorProfileTab extends StatefulWidget {
  const DonorProfileTab({super.key});

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  String _fullName = 'Blood Donor';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user's full name from Firestore
  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final firstName = data['firstName'] as String? ?? '';
          final surname = data['surname'] as String? ?? '';
          setState(() {
            _fullName = '${firstName.trim()} ${surname.trim()}'.trim();
            if (_fullName.isEmpty) _fullName = 'Blood Donor';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Handles user logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout == true && context.mounted) {
        await FirebaseAuth.instance.signOut();
        debugPrint('User logged out successfully');

        if (context.mounted) {
          context.go(AppRoutes.welcome);
        }
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles opening notification settings
  Future<void> _handleNotificationSettings(BuildContext context) async {
    try {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notification Settings'),
          content: const Text(
            'You will be redirected to your device settings where you can manage notification preferences for Hema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpen == true && context.mounted) {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
      }
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles account deletion
  Future<void> _handleDeleteAccount(BuildContext context) async {
    try {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete My Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.\n\nAll your data will be permanently deleted from the Hema servers in 30 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      );

      if (shouldDelete == true && context.mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          // Call cloud function to delete user account
          final functions = FirebaseFunctions.instance;
          final result = await functions.httpsCallable('deleteUser').call();

          debugPrint('Account deletion result: ${result.data}');

          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading dialog

            // Show success message
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Account Deleted'),
                content: const Text(
                  'Your account has been deleted. All your data will be permanently removed from our servers in 30 days.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );

            if (context.mounted) {
              context.go(AppRoutes.welcome);
            }
          }
        } catch (e) {
          debugPrint('Error deleting account: $e');
          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading dialog

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete account: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in delete account dialog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Color(0xFF1A1C1E), Color(0xFF2D1B1B)]
              : [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Profile',
                style: context.textStyles.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Text(
                        _fullName,
                        style: context.textStyles.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
              ProfileMenuItem(
                icon: Icons.person_outline,
                title: 'Personal Details',
                onTap: () => context.push(AppRoutes.personalDetails),
              ),
              const SizedBox(height: 12),
              ProfileMenuItem(
                  icon: Icons.history, title: 'Donation History', onTap: () => context.push(AppRoutes.donationHistory)),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => _handleNotificationSettings(context),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => context.push(AppRoutes.helpSupport),
              ),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () => _handleLogout(context),
                isDestructive: true,
              ),
              const SizedBox(height: 24),
              ProfileMenuItem(
                icon: Icons.delete_forever,
                title: 'Delete My Account',
                onTap: () => _handleDeleteAccount(context),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile menu item widget (reused from provider home)
class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: context.textStyles.titleMedium?.copyWith(
                      color: isDestructive
                          ? Colors.red
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.w500,
                    ),
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
      ),
    );
  }
}
