import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/screens/splash_screen.dart';
import 'package:hema/screens/welcome_page.dart';
import 'package:hema/screens/consent_page.dart';
import 'package:hema/screens/privacy_policy_page.dart';
import 'package:hema/screens/terms_of_service_page.dart';
import 'package:hema/screens/user_type_selection_page.dart';
import 'package:hema/screens/registration_page.dart';
import 'package:hema/screens/login_page.dart';
import 'package:hema/screens/forgot_password_page.dart';
import 'package:hema/screens/donor_consent_page.dart';
import 'package:hema/screens/donor_onboarding_page.dart';
import 'package:hema/screens/provider_onboarding_page.dart';
import 'package:hema/screens/home_page.dart';
import 'package:hema/screens/donor_home_page.dart';
import 'package:hema/screens/personal_details_page.dart';
import 'package:hema/screens/provider_home_page.dart';
import 'package:hema/screens/organization_details_page.dart';
import 'package:hema/screens/create_request_page.dart';
import 'package:hema/screens/request_chat_page.dart';
import 'package:hema/screens/help_support_page.dart';
import 'package:hema/screens/donation_info_page.dart';
import 'package:hema/screens/provider_donor_chat_page.dart';
import 'package:hema/screens/rewards_page.dart';
import 'package:hema/screens/donation_history_page.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/models/user_model.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const WelcomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.consent,
        name: 'consent',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ConsentPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacyPolicy',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const PrivacyPolicyPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        name: 'termsOfService',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const TermsOfServicePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.userTypeSelection,
        name: 'userTypeSelection',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const UserTypeSelectionPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.registration,
        name: 'registration',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const RegistrationPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.donorConsent,
        name: 'donorConsent',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const DonorConsentPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.donorOnboarding,
        name: 'donorOnboarding',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const DonorOnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.providerOnboarding,
        name: 'providerOnboarding',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ProviderOnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.donorHome,
        name: 'donorHome',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const DonorHomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.personalDetails,
        name: 'personalDetails',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const PersonalDetailsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.providerHome,
        name: 'providerHome',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ProviderHomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.organizationDetails,
        name: 'organizationDetails',
        pageBuilder: (context, state) {
          final request = state.extra as BloodRequestModel?;
          return NoTransitionPage(
            child: OrganizationDetailsPage(request: request),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createRequest,
        name: 'createRequest',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const CreateRequestPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.requestChat,
        name: 'requestChat',
        pageBuilder: (context, state) {
          final request = state.extra as BloodRequestModel;
          return NoTransitionPage(
            child: RequestChatPage(request: request),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        name: 'helpSupport',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const HelpSupportPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.donationInfo,
        name: 'donationInfo',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const DonationInfoPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.providerDonorChat,
        name: 'providerDonorChat',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return NoTransitionPage(
            child: ProviderDonorChatPage(
              donor: args['donor'] as UserModel,
              request: args['request'] as BloodRequestModel,
              providerId: args['providerId'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.rewards,
        name: 'rewards',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const RewardsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.donationHistory,
        name: 'donationHistory',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const DonationHistoryPage(),
        ),
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String consent = '/consent';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
  static const String userTypeSelection = '/user-type-selection';
  static const String registration = '/registration';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String donorConsent = '/donor-consent';
  static const String donorOnboarding = '/donor-onboarding';
  static const String providerOnboarding = '/provider-onboarding';
  static const String home = '/home';
  static const String donorHome = '/donor-home';
  static const String personalDetails = '/personal-details';
  static const String providerHome = '/provider-home';
  static const String organizationDetails = '/organization-details';
  static const String createRequest = '/create-request';
  static const String requestChat = '/request-chat';
  static const String helpSupport = '/help-support';
  static const String donationInfo = '/donation-info';
  static const String providerDonorChat = '/provider-donor-chat';
  static const String rewards = '/rewards';
  static const String donationHistory = '/donation-history';
}
