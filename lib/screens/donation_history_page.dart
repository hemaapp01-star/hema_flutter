import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hema/models/donation_model.dart';
import 'package:hema/theme.dart';

/// Page displaying user's donation history
class DonationHistoryPage extends StatelessWidget {
  const DonationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Donation History'),
        ),
        body: const Center(child: Text('Please log in to view donation history')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Donation History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donorId', isEqualTo: user.uid)
            .orderBy('donationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final donations = snapshot.data?.docs
              .map((doc) => DonationModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList() ?? [];

          if (donations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bloodtype_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('No donations yet', style: context.textStyles.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Your donation history will appear here', style: context.textStyles.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.paddingMd,
            itemCount: donations.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => DonationHistoryCard(donation: donations[index]),
          );
        },
      ),
    );
  }
}

/// Card widget displaying individual donation information
class DonationHistoryCard extends StatelessWidget {
  final DonationModel donation;

  const DonationHistoryCard({super.key, required this.donation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.bloodtype, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(donation.providerName, style: context.textStyles.titleMedium?.semiBold),
                      const SizedBox(height: 4),
                      Text(dateFormat.format(donation.donationDate), style: context.textStyles.bodySmall?.withColor(theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(donation.bloodType, style: context.textStyles.labelMedium?.semiBold.withColor(theme.colorScheme.onPrimary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.md),
            DonationInfoRow(icon: Icons.location_on_outlined, label: 'Location', value: donation.location),
            const SizedBox(height: AppSpacing.sm),
            DonationInfoRow(icon: Icons.water_drop_outlined, label: 'Component', value: donation.component),
            const SizedBox(height: AppSpacing.sm),
            DonationInfoRow(icon: Icons.insights_outlined, label: 'Units Collected', value: '${donation.unitsCollected} unit${donation.unitsCollected > 1 ? 's' : ''}'),
            if (donation.notes != null && donation.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(donation.notes!, style: context.textStyles.bodySmall?.withColor(theme.colorScheme.onSurfaceVariant))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Row widget displaying donation information with icon and label
class DonationInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DonationInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text('$label:', style: context.textStyles.bodySmall?.withColor(theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(value, style: context.textStyles.bodySmall?.medium)),
      ],
    );
  }
}
