import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/nav.dart';
import 'package:hema/theme.dart';
import 'package:hema/models/user_model.dart';

/// Splash screen displayed when app launches
///
/// Shows the app logo/branding and automatically navigates
/// to the appropriate page based on auth and onboarding status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for 2 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // If not authenticated, go to welcome
      if (user == null) {
        debugPrint('No authenticated user, navigating to welcome');
        context.go(AppRoutes.welcome);
        return;
      }

      debugPrint('User authenticated: ${user.uid}');

      // Fetch user document to check onboarding status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('User document does not exist, navigating to user type selection');
        context.go(AppRoutes.userTypeSelection);
        return;
      }

      final userData = UserModel.fromJson(userDoc.data()!);
      
      // Check if onboarding is complete
      if (!userData.onboarded) {
        debugPrint('User not onboarded, redirecting to onboarding');
        
        // Route to appropriate onboarding based on user type
        if (userData.userType == UserType.donor) {
          debugPrint('Redirecting donor to consent page');
          context.go(AppRoutes.donorConsent);
        } else if (userData.userType == UserType.provider) {
          debugPrint('Redirecting provider to onboarding');
          context.go(AppRoutes.providerOnboarding);
        } else {
          debugPrint('User type not set, redirecting to user type selection');
          context.go(AppRoutes.userTypeSelection);
        }
        return;
      }

      // User is authenticated and onboarded, navigate to home
      debugPrint('User onboarded, navigating to home');
      if (userData.userType == UserType.donor) {
        context.go(AppRoutes.donorHome);
      } else if (userData.userType == UserType.provider) {
        context.go(AppRoutes.providerHome);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      if (mounted) {
        context.go(AppRoutes.welcome);
      }
    }
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(flex: 1),
                // Replicating LogoCard structure from WelcomePage
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x00303030) : const Color(0x00FFFFFF),
                    borderRadius: BorderRadius.circular(125),
                  ),
                  width: 250,
                  height: 250,
                  alignment: Alignment.center,
                  child: Center(
                    child: Image.asset(
                      'assets/images/hema_logo.png',
                      width: 200,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.favorite,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Invisible 'Hema' text to maintain layout
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    'Hema',
                    style: context.textStyles.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Invisible Subtitle 1
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    'Be a Hero in someone\'s story',
                    style: context.textStyles.titleMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                // Invisible Subtitle 2
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    'Donate blood, save lives',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 1),
                const SizedBox(height: 32),
                // Invisible Get Started Button area
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(child: Text('Get Started')),
                  ),
                ),
                const SizedBox(height: 16),
                // Invisible Login Link area
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Already have an account? Log In',
                      style: context.textStyles.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Medical disclaimer in the same position as Terms/Privacy
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Hema is a tool to facilitate connections. Always seek a doctor’s advice in addition to using this app and before making any medical decisions.',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
