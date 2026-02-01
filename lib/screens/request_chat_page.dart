import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hema/nav.dart';

/// Request Agent Chat Page - LLM-powered chat for coordinating blood requests
class RequestChatPage extends StatefulWidget {
  final BloodRequestModel request;

  const RequestChatPage({super.key, required this.request});

  @override
  State<RequestChatPage> createState() => _RequestChatPageState();
}

class _RequestChatPageState extends State<RequestChatPage> {
  List<UserModel> _matchedDonorUsers = [];
  bool _loadingDonors = true;

  @override
  void initState() {
    super.initState();
    _loadMatchedDonors();
  }

  Future<void> _loadMatchedDonors() async {
    if (widget.request.matchedDonors.isEmpty) {
      setState(() => _loadingDonors = false);
      return;
    }

    try {
      final donorDocs = await Future.wait(
        widget.request.matchedDonors.map((donorId) =>
            FirebaseFirestore.instance.collection('users').doc(donorId).get()),
      );

      final donors = donorDocs
          .where((doc) => doc.exists)
          .map((doc) => UserModel.fromJson(doc.data()!))
          .toList();

      setState(() {
        _matchedDonorUsers = donors;
        _loadingDonors = false;
      });
    } catch (e) {
      debugPrint('Error loading matched donors: $e');
      setState(() => _loadingDonors = false);
    }
  }

  void _showRequestUpdateBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Request',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select an action for this blood request',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _markRequestFilled();
                },
                icon: const Icon(Icons.check_circle, size: 24),
                label: const Text(
                  'Request Filled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteRequest();
                },
                icon: const Icon(Icons.delete, size: 24),
                label: const Text(
                  'Delete Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _markRequestFilled() async {
    try {
      // Update the request status to filled in Firestore
      await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(widget.request.providerId)
          .collection('requests')
          .doc(widget.request.id)
          .update({
        'status': 'fulfilled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Set activeRequest to false for all matched donors
      if (widget.request.matchedDonors.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final donorId in widget.request.matchedDonors) {
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(donorId),
            {
              'activeRequest': false,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
        await batch.commit();
        debugPrint('✅ Set activeRequest to false for all matched donors');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request marked as filled successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        context.pop();
      }
    } catch (e) {
      debugPrint('Error marking request as filled: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark request as filled: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRequest() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this blood request? This action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      // Set activeRequest to false for all matched donors
      if (widget.request.matchedDonors.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final donorId in widget.request.matchedDonors) {
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(donorId),
            {
              'activeRequest': false,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
        await batch.commit();
        debugPrint('✅ Set activeRequest to false for all matched donors');
      }

      // Delete the request from Firestore
      await FirebaseFirestore.instance
          .collection('healthcare_providers')
          .doc(widget.request.providerId)
          .collection('requests')
          .doc(widget.request.id)
          .delete();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        context.pop();
      }
    } catch (e) {
      debugPrint('Error deleting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Request Coordinator',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Request summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.title,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.water_drop,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.request.component.displayName} - ${widget.request.bloodGroup}',
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.request.quantity} units • ${widget.request.urgency.displayName} urgency',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Section title for matched donors
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Matched Donors',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),

          // Matched donors list
          Expanded(
            child: _loadingDonors
                ? const Center(child: CircularProgressIndicator())
                : _matchedDonorUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matched donors yet',
                              style: context.textStyles.titleMedium?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Donors who accept this request will appear here',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _matchedDonorUsers.length,
                        itemBuilder: (context, index) {
                          final donor = _matchedDonorUsers[index];
                          return MatchedDonorListCard(
                            donor: donor,
                            request: widget.request,
                            isDark: isDark,
                          );
                        },
                      ),
          ),

          // Sticky Update Request button at bottom
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showRequestUpdateBottomSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Matched donor list card widget
class MatchedDonorListCard extends StatelessWidget {
  final UserModel donor;
  final BloodRequestModel request;
  final bool isDark;

  const MatchedDonorListCard({
    super.key,
    required this.donor,
    required this.request,
    required this.isDark,
  });

  void _showUpdateStatusBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Donor Status',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the outcome for ${donor.firstName}',
              style: context.textStyles.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _StatusButton(
              icon: Icons.check_circle,
              label: 'Successfully Donated',
              color: Colors.green,
              onPressed: () {
                Navigator.pop(context);
                _updateDonorStatus(context, 'successfully_donated');
              },
            ),
            const SizedBox(height: 12),
            _StatusButton(
              icon: Icons.cancel,
              label: 'Failed Screening',
              color: Colors.orange,
              onPressed: () {
                Navigator.pop(context);
                _updateDonorStatus(context, 'failed_screening');
              },
            ),
            const SizedBox(height: 12),
            _StatusButton(
              icon: Icons.person_off,
              label: 'Did Not Show',
              color: Colors.red,
              onPressed: () {
                Navigator.pop(context);
                _updateDonorStatus(context, 'did_not_show');
              },
            ),
            const SizedBox(height: 12),
            _StatusButton(
              icon: Icons.more_horiz,
              label: 'Other',
              color: Colors.grey,
              onPressed: () {
                Navigator.pop(context);
                _showOtherStatusBottomSheet(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showOtherStatusBottomSheet(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Custom Status',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide a custom status for ${donor.firstName}',
              style: context.textStyles.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Custom Status',
                hintText: 'e.g., Rescheduled for next week',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final customStatus = controller.text.trim();
                      if (customStatus.isNotEmpty) {
                        Navigator.pop(context);
                        _updateDonorStatus(context, customStatus);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a status'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _updateDonorStatus(BuildContext context, String status) {
    // TODO: Implement status update logic with Firestore
    debugPrint('Updating donor ${donor.id} status to: $status');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to: ${_getStatusDisplayName(status)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'successfully_donated':
        return 'Successfully Donated';
      case 'failed_screening':
        return 'Failed Screening';
      case 'did_not_show':
        return 'Did Not Show';
      case 'other':
        return 'Other';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                child: Text(
                  donor.firstName[0].toUpperCase(),
                  style: context.textStyles.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.fullName,
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (donor.bloodType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          donor.bloodType!.displayName,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (donor.city != null || donor.daytimeAddress != null) ...[
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    donor.daytimeAddress ?? donor.city ?? '',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (donor.phoneNumber != null) ...[
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    donor.phoneNumber!,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (donor.totalDonations != null) ...[
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${donor.totalDonations} total donations',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              final currentUser = FirebaseAuth.instance.currentUser;
              final ctx = context;
              
              if (currentUser == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('You must be logged in to chat'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                // Fetch the user's Firestore document to get providerId
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();

                if (!userDoc.exists) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('User data not found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final userData = UserModel.fromJson(userDoc.data()!);
                
                if (userData.providerId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Provider ID not found for this user'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Navigate to chat page with the correct providerId
                ctx.push(
                  AppRoutes.providerDonorChat,
                  extra: {
                    'donor': donor,
                    'request': request,
                    'providerId': userData.providerId!,
                  },
                );
              } catch (e) {
                debugPrint('Error fetching user data: $e');
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Failed to load user data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.chat, size: 20),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showUpdateStatusBottomSheet(context),
            icon: const Icon(Icons.update, size: 20),
            label: const Text('Update Status'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status button widget for the bottom sheet
class _StatusButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
