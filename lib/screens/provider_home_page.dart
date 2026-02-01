import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/models/healthcare_provider_model.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/services/firebase_messaging_service.dart';
import 'package:app_settings/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider dashboard/home page
class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  int _selectedIndex = 0;

  List<Widget> _getPages(bool isVerified, String? providerId) {
    return [
      DashboardTab(isVerified: isVerified, providerId: providerId),
      RequestsTab(isVerified: isVerified, providerId: providerId),
      const ProfileTab(),
    ];
  }

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
        debugPrint('User document not found, redirecting to user type selection');
        if (mounted) context.go(AppRoutes.userTypeSelection);
        return;
      }

      final userData = UserModel.fromJson(userDoc.data()!);
      
      if (!userData.onboarded) {
        debugPrint('User has not completed onboarding, redirecting to provider onboarding');
        if (mounted) context.go(AppRoutes.providerOnboarding);
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots()
          : null,
      builder: (context, userSnapshot) {
        bool isUserVerified = false;
        String? providerId;

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = UserModel.fromJson(
              userSnapshot.data!.data() as Map<String, dynamic>);
          providerId = userData.providerId;
          isUserVerified = userData.isVerified ?? false;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: providerId != null
              ? FirebaseFirestore.instance
                  .collection('healthcare_providers')
                  .doc(providerId)
                  .snapshots()
              : null,
          builder: (context, providerSnapshot) {
            bool isProviderVerified = false;

            if (providerSnapshot.hasData && providerSnapshot.data!.exists) {
              final providerData = HealthcareProviderModel.fromJson(
                  providerSnapshot.data!.data() as Map<String, dynamic>);
              isProviderVerified = providerData.isVerified;
            }

            final isVerified = isUserVerified || isProviderVerified;
            final pages = _getPages(isVerified, providerId);

            return Scaffold(
              body: pages[_selectedIndex],
              floatingActionButton: _selectedIndex == 1
                  ? AddRequestButton(
                      isVerified: isVerified, providerId: providerId)
                  : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) => setState(() => _selectedIndex = index),
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Theme.of(context).colorScheme.primary,
                  unselectedItemColor: Colors.grey,
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard), label: 'Dashboard'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.notifications), label: 'Requests'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.person), label: 'Profile'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Floating action button for adding blood requests
class AddRequestButton extends StatelessWidget {
  final bool isVerified;
  final String? providerId;

  const AddRequestButton({
    super.key,
    required this.isVerified,
    required this.providerId,
  });

  Future<void> _handleNewRequest(BuildContext context) async {
    try {
      // Check current permission status
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Already authorized, proceed
        if (context.mounted) context.push('/create-request');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool('has_requested_notifications_provider') ?? false;

      if (hasRequested) {
        // User previously saw the dialog and either denied or accepted (but now it's not authorized)
        // Show silent warning (toast/snackbar) and proceed
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications are disabled. You won\'t be notified of matches unless you enable them in settings.'),
              duration: Duration(seconds: 3),
            ),
          );
          context.push('/create-request');
        }
      } else {
        // First time asking
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Enable Notifications?'),
                content: const Text(
                  'To receive instant updates when a matched donor is found for your request, Hema needs permission to send you notifications.',
                ),
                actions: [
                  TextButton(
                    child: const Text('No Thanks'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await prefs.setBool('has_requested_notifications_provider', true);
                      if (context.mounted) context.push('/create-request');
                    },
                  ),
                  TextButton(
                    child: const Text('Enable'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await prefs.setBool('has_requested_notifications_provider', true);
                      
                      // Request actual permission
                      await FirebaseMessagingService.requestPermissionAndSetupToken();
                      
                      // Proceed regardless of result (if they denied system dialog, next time they get the snackbar)
                      if (context.mounted) context.push('/create-request');
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling new request button: $e');
      // Fallback
      if (context.mounted) context.push('/create-request');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () => _handleNewRequest(context),
      backgroundColor: Colors.white,
      foregroundColor: Theme.of(context).colorScheme.primary,
      icon: const Icon(Icons.add, size: 28),
      label: const Text('New Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      elevation: 6,
    );
  }
}

/// Dashboard tab showing key metrics
class DashboardTab extends StatelessWidget {
  final bool isVerified;
  final String? providerId;

  const DashboardTab({
    super.key,
    required this.isVerified,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: StreamBuilder<DocumentSnapshot>(
          stream: providerId != null
              ? FirebaseFirestore.instance
                  .collection('healthcare_providers')
                  .doc(providerId)
                  .snapshots()
              : null,
          builder: (context, providerSnapshot) {
            int activeRequests = 0;
            int bloodInventory = 0;
            int donorsMatched = 0;
            int donationsThisMonth = 0;

            if (providerSnapshot.hasData && providerSnapshot.data!.exists) {
              final providerData = HealthcareProviderModel.fromJson(
                  providerSnapshot.data!.data() as Map<String, dynamic>);
              activeRequests = providerData.activeRequests;
              bloodInventory = providerData.bloodInventory;
              donorsMatched = providerData.donorsMatched;
              donationsThisMonth = providerData.donationsThisMonth;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Dashboard',
                  style: context.textStyles.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (!isVerified) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your organisation\'s account is pending verification',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Verification status card (only show if not verified)
                if (!isVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.orange, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Pending',
                                style:
                                    context.textStyles.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your operating license is being reviewed. You will receive an email once your account is activated.',
                                style: context.textStyles.bodySmall?.copyWith(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Metrics grid
                Text(
                  'Quick Stats',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                        context,
                        'Active Requests',
                        '$activeRequests',
                        Icons.notification_important,
                        isDark),
                    _buildStatCard(context, 'Blood Inventory',
                        '$bloodInventory Units', Icons.water_drop, isDark),
                    _buildStatCard(context, 'Donors Matched', '$donorsMatched',
                        Icons.people, isDark),
                    _buildStatCard(context, 'This Month',
                        '$donationsThisMonth Donations', Icons.calendar_today, isDark),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: context.textStyles.bodySmall?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Requests tab for blood donation requests
class RequestsTab extends StatelessWidget {
  final bool isVerified;
  final String? providerId;

  const RequestsTab({
    super.key,
    required this.isVerified,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Blood Requests',
              style: context.textStyles.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (!isVerified)
              Text(
                'Available after verification',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: !isVerified
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Feature Locked',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This feature will be available once your account is verified.',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: providerId != null
                          ? FirebaseFirestore.instance
                              .collection('healthcare_providers')
                              .doc(providerId)
                              .collection('requests')
                              .orderBy('createdAt', descending: true)
                              .snapshots()
                          : null,
                      builder: (context, requestsSnapshot) {
                        if (requestsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!requestsSnapshot.hasData ||
                            requestsSnapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_outlined,
                                    size: 80, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'No Requests Yet',
                                  style: context.textStyles.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first blood request to get started.',
                                  style: context.textStyles.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final allRequests = requestsSnapshot.data!.docs
                            .map((doc) => BloodRequestModel.fromJson(
                                  doc.data() as Map<String, dynamic>,
                                ))
                            .toList();

                        // Filter requests
                        final filledRequests = allRequests
                            .where((r) =>
                                r.status == RequestStatus.fulfilled ||
                                r.status.name == 'filled') // Handle potential legacy string 'filled'
                            .toList();
                        
                        final openRequests = allRequests
                            .where((r) =>
                                r.status != RequestStatus.fulfilled &&
                                r.status.name != 'filled')
                            .toList();

                        if (allRequests.isEmpty) {
                           return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_outlined,
                                    size: 80, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'No Requests Yet',
                                  style: context.textStyles.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                           );
                        }

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Open Requests Section
                              if (openRequests.isNotEmpty) ...[
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: openRequests.length,
                                  itemBuilder: (context, index) {
                                    final request = openRequests[index];
                                    return GestureDetector(
                                      onTap: () => context.push('/request-chat',
                                          extra: request),
                                      child: BloodRequestCard(
                                          request: request, isDark: isDark),
                                    );
                                  },
                                ),
                              ] else if (filledRequests.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                                  child: Center(
                                    child: Text(
                                      'No active requests',
                                      style: context.textStyles.bodyLarge?.copyWith(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Filled Requests Section
                              if (filledRequests.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    title: Text(
                                      'Filled Requests (${filledRequests.length})',
                                      style: context.textStyles.titleMedium?.copyWith(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    tilePadding: EdgeInsets.zero,
                                    children: [
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: filledRequests.length,
                                        itemBuilder: (context, index) {
                                          final request = filledRequests[index];
                                          // Opacity to indicating filled status visually as well
                                          return Opacity(
                                            opacity: 0.7,
                                            child: GestureDetector(
                                              onTap: () => context.push('/request-chat',
                                                  extra: request),
                                              child: BloodRequestCard(
                                                  request: request, isDark: isDark),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              // Extra padding at bottom for FAB
                              const SizedBox(height: 80), 
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blood Request Card Widget
class BloodRequestCard extends StatelessWidget {
  final BloodRequestModel request;
  final bool isDark;

  const BloodRequestCard({
    super.key,
    required this.request,
    required this.isDark,
  });

  Color _getUrgencyColor() {
    switch (request.urgency) {
      case UrgencyLevel.critical:
        return const Color(0xFFD32F2F);
      case UrgencyLevel.high:
        return const Color(0xFFF57C00);
      case UrgencyLevel.medium:
        return const Color(0xFFFBC02D);
      case UrgencyLevel.low:
        return const Color(0xFF388E3C);
    }
  }

  Color _getStatusColor() {
    switch (request.status) {
      case RequestStatus.open:
        return Colors.blue;
      case RequestStatus.matched:
        return Colors.orange;
      case RequestStatus.fulfilled:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getUrgencyColor().withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with urgency badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getUrgencyColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getUrgencyColor()),
                ),
                child: Text(
                  request.urgency.displayName.toUpperCase(),
                  style: context.textStyles.labelSmall?.copyWith(
                    color: _getUrgencyColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Blood group and quantity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.water_drop,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.bloodGroup,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${request.quantity} ${request.quantity == 1 ? 'Unit' : 'Units'} needed',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notes
          if (request.notes.isNotEmpty) ...[
            Text(
              request.notes,
              style: context.textStyles.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Additional details row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (request.requiredBy != null)
                _buildDetailChip(
                  context,
                  Icons.calendar_today,
                  'Required by ${DateFormat('MMM dd').format(request.requiredBy!)}',
                ),
              if (request.patientName != null &&
                  request.patientName!.isNotEmpty)
                _buildDetailChip(
                  context,
                  Icons.person,
                  request.patientName!,
                ),
              _buildDetailChip(
                context,
                Icons.people,
                '${request.matchedDonors.length} matched',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status chip
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(), size: 16, color: _getStatusColor()),
                    const SizedBox(width: 6),
                    Text(
                      request.status.displayName,
                      style: context.textStyles.labelMedium?.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.textStyles.bodySmall?.copyWith(
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    switch (request.status) {
      case RequestStatus.open:
        return Icons.radio_button_unchecked;
      case RequestStatus.matched:
        return Icons.link;
      case RequestStatus.fulfilled:
        return Icons.check_circle;
      case RequestStatus.cancelled:
        return Icons.cancel;
    }
  }
}

/// Profile tab for provider settings
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

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

              // Profile avatar and name - centered
              StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                    : null,
                builder: (context, snapshot) {
                  String displayName = 'Provider';
                  String organizationName = '';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = UserModel.fromJson(
                        snapshot.data!.data() as Map<String, dynamic>);
                    displayName = userData.fullName;

                    if (userData.organizationName != null &&
                        userData.organizationName!.isNotEmpty) {
                      organizationName = userData.organizationName!
                          .split(' ')
                          .map((word) => word.isNotEmpty
                              ? word[0].toUpperCase() +
                                  word.substring(1).toLowerCase()
                              : '')
                          .join(' ');
                    }
                  }

                  return Column(
                    children: [
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
                          child: const Icon(Icons.local_hospital,
                              size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          displayName,
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (organizationName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            organizationName,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Menu items using ProfileMenuItem widget
              _ProfileMenuItem(
                icon: Icons.business,
                title: 'Organization Details',
                onTap: () => context.push('/organization-details'),
              ),
              const SizedBox(height: 12),
              _ProfileMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notification Settings',
                onTap: () =>
                    AppSettings.openAppSettings(type: AppSettingsType.notification),
              ),
              const SizedBox(height: 12),
              _ProfileMenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => context.push('/help-support'),
              ),
              const SizedBox(height: 12),
              _ProfileMenuItem(
                icon: Icons.logout,
                title: 'Sign Out',
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    context.go('/');
                  }
                },
                isDestructive: true,
              ),
              const SizedBox(height: 32),
              _ProfileMenuItem(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Account'),
                      content: const Text(
                        'Are you sure you want to delete your account? This action cannot be undone and all your information will be permanently deleted within 30 days.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        debugPrint('No user logged in');
                        return;
                      }

                      // Call the deleteUser cloud function
                      final callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
                      final result = await callable.call();
                      
                      debugPrint('Delete user result: $result');

                      if (context.mounted) {
                        // Show snackbar for 30 seconds
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'All your information will be deleted within 30 days. You will need to create another account to use Hema.',
                            ),
                            duration: Duration(seconds: 30),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        // Wait 30 seconds then logout
                        await Future.delayed(const Duration(seconds: 30));
                        
                        if (context.mounted) {
                          await FirebaseAuth.instance.signOut();
                          context.go('/');
                        }
                      }
                    } catch (e) {
                      debugPrint('Error deleting account: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete account: ${e.toString()}'),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                },
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile menu item widget (matching donor profile style)
class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileMenuItem({
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
