import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hema/models/user_model.dart';

/// User type selection page - choose between Donor or Healthcare Provider
class UserTypeSelectionPage extends StatefulWidget {
  const UserTypeSelectionPage({super.key});

  @override
  State<UserTypeSelectionPage> createState() => _UserTypeSelectionPageState();
}

class _UserTypeSelectionPageState extends State<UserTypeSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectUserType(BuildContext context, UserType userType) async {
    debugPrint('_selectUserType called with userType: $userType');
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${user?.uid ?? "null"}');
      if (user == null) {
        debugPrint('Error: No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Authentication error. Please log in again.')),
          );
        }
        return;
      }

      debugPrint('Fetching existing user document...');
      // Fetch existing user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      UserModel userModel;
      if (userDoc.exists) {
        // Update existing user document with selected user type
        debugPrint('User document exists, updating with user type');
        final existingUser = UserModel.fromJson(userDoc.data()!);
        userModel = existingUser.copyWith(
          userType: userType,
          updatedAt: DateTime.now(),
        );
      } else {
        // Create new user document if it doesn't exist
        debugPrint('User document does not exist, creating new one');
        final now = DateTime.now();
        // Parse firstName and surname from displayName
        final displayNameParts = (user.displayName ?? '').split(' ');
        final firstName =
            displayNameParts.isNotEmpty ? displayNameParts.first : '';
        final surname = displayNameParts.length > 1
            ? displayNameParts.sublist(1).join(' ')
            : '';

        userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          firstName: firstName,
          surname: surname,
          userType: userType,
          createdAt: now,
          updatedAt: now,
          onboarded: false,
        );
      }

      debugPrint('Saving user model to Firestore...');
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userModel.toJson());

      debugPrint('User type saved: $userType');
      debugPrint('Mounted: $mounted');

      // Navigate to appropriate onboarding
      if (mounted) {
        final route = userType == UserType.donor
            ? AppRoutes.donorConsent
            : AppRoutes.providerOnboarding;
        debugPrint('Navigating to: $route');
        context.go(route);
        debugPrint('Navigation command executed');
      } else {
        debugPrint('Widget not mounted, skipping navigation');
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving user type: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    debugPrint('_selectUserType completed');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C1517), // Dark burgundy
                    Color(0xFF1A1C1E), // Dark surface
                    Color(0xFF0D0E0F), // Very dark
                  ],
                  stops: [0.0, 0.5, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFE8E8), // Light pink
                    Color(0xFFFFF0F0), // Lighter pink
                    Color(0xFFFFF8F8), // Very light pink
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/hema_logo_2_1.png',
                            width: 200,
                            height: 200,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to Hema',
                            style: context.textStyles.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'How would you like to use Hema?',
                            style: context.textStyles.bodyLarge?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),
                          UserTypeCard(
                            icon: Icons.bloodtype_rounded,
                            title: 'I\'m a Donor',
                            description: 'Help save lives by donating blood',
                            onTap: () {
                              debugPrint('Donor card tapped');
                              _selectUserType(context, UserType.donor);
                            },
                          ),
                          const SizedBox(height: 20),
                          UserTypeCard(
                            icon: Icons.local_hospital_rounded,
                            title: 'I\'m a Healthcare Provider',
                            description: 'Request blood for patients in need',
                            onTap: () {
                              debugPrint('Provider card tapped');
                              _selectUserType(context, UserType.provider);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card widget for user type selection
class UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const UserTypeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('UserTypeCard InkWell tapped: $title');
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
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
