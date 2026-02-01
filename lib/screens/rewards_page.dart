import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/theme.dart';

/// Rewards page showing donor achievements and badges
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _currentUser = UserModel.fromJson(doc.data()!);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Rewards', style: context.textStyles.titleLarge),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Text(
                    'Unable to load your rewards',
                    style: context.textStyles.bodyLarge,
                  ),
                )
              : SingleChildScrollView(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroLevelCard(isDark),
                      const SizedBox(height: 20),
                      _buildImpactStats(isDark),
                      const SizedBox(height: 28),
                      Text(
                        'Badges & Achievements',
                        style: context.textStyles.titleLarge?.semiBold,
                      ),
                      const SizedBox(height: 16),
                      _buildBadgesGrid(isDark),
                      const SizedBox(height: 28),
                      Text(
                        'Milestones',
                        style: context.textStyles.titleLarge?.semiBold,
                      ),
                      const SizedBox(height: 16),
                      _buildMilestones(isDark),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroLevelCard(bool isDark) {
    final donations = _currentUser?.totalDonations ?? 0;
    final heroLevel = _currentUser?.heroLevelName ?? 'New Hero';
    final progress = _calculateLevelProgress(donations);
    final nextMilestone = _getNextMilestone(donations);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [DarkModeColors.darkPrimaryContainer, DarkModeColors.darkTertiary]
              : [LightModeColors.lightPrimary, LightModeColors.lightTertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.military_tech,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            heroLevel,
            style: context.textStyles.headlineMedium?.bold.withColor(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '$donations ${donations == 1 ? 'Donation' : 'Donations'}',
            style: context.textStyles.bodyLarge?.withColor(Colors.white.withValues(alpha: 0.9)),
          ),
          if (nextMilestone != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${nextMilestone - donations} more to $nextMilestone donations',
              style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactStats(bool isDark) {
    final donations = _currentUser?.totalDonations ?? 0;
    final livesSaved = _currentUser?.livesSaved ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.favorite,
            value: livesSaved.toString(),
            label: 'Lives Saved',
            color: Colors.red,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.water_drop,
            value: donations.toString(),
            label: 'Donations',
            color: Colors.blue,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesGrid(bool isDark) {
    final earnedBadges = _currentUser?.badges ?? [];
    final allBadges = _getAllBadges();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allBadges.length,
      itemBuilder: (context, index) {
        final badge = allBadges[index];
        final isEarned = earnedBadges.contains(badge.id);
        return _BadgeCard(
          badge: badge,
          isEarned: isEarned,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildMilestones(bool isDark) {
    final donations = _currentUser?.totalDonations ?? 0;
    final milestones = [
      _Milestone(count: 1, title: 'First Donation', subtitle: 'Begin your hero journey'),
      _Milestone(count: 5, title: 'Bronze Hero', subtitle: '5 lives saved'),
      _Milestone(count: 10, title: 'Silver Hero', subtitle: '10 lives saved'),
      _Milestone(count: 25, title: 'Gold Hero', subtitle: '25 lives saved'),
      _Milestone(count: 50, title: 'Platinum Hero', subtitle: '50 lives saved'),
      _Milestone(count: 100, title: 'Diamond Hero', subtitle: '100 lives saved'),
    ];

    return Column(
      children: milestones.map((milestone) {
        final isAchieved = donations >= milestone.count;
        return _MilestoneCard(
          milestone: milestone,
          isAchieved: isAchieved,
          isDark: isDark,
        );
      }).toList(),
    );
  }

  List<_Badge> _getAllBadges() => [
        _Badge(
          id: 'first_donation',
          icon: Icons.star,
          name: 'First Drop',
          description: 'Complete your first donation',
          requiredDonations: 1,
        ),
        _Badge(
          id: 'bronze_donor',
          icon: Icons.workspace_premium,
          name: 'Bronze',
          description: '5 donations completed',
          requiredDonations: 5,
        ),
        _Badge(
          id: 'silver_donor',
          icon: Icons.workspace_premium,
          name: 'Silver',
          description: '10 donations completed',
          requiredDonations: 10,
        ),
        _Badge(
          id: 'gold_donor',
          icon: Icons.workspace_premium,
          name: 'Gold',
          description: '25 donations completed',
          requiredDonations: 25,
        ),
        _Badge(
          id: 'platinum_donor',
          icon: Icons.diamond,
          name: 'Platinum',
          description: '50 donations completed',
          requiredDonations: 50,
        ),
        _Badge(
          id: 'lifesaver',
          icon: Icons.health_and_safety,
          name: 'Lifesaver',
          description: 'Saved 30+ lives',
          requiredDonations: 10,
        ),
        _Badge(
          id: 'consistent_donor',
          icon: Icons.event_repeat,
          name: 'Consistent',
          description: 'Donate regularly',
          requiredDonations: 3,
        ),
        _Badge(
          id: 'early_bird',
          icon: Icons.wb_sunny,
          name: 'Early Bird',
          description: 'Donate before 9 AM',
          requiredDonations: 1,
        ),
        _Badge(
          id: 'champion',
          icon: Icons.emoji_events,
          name: 'Champion',
          description: '100 donations milestone',
          requiredDonations: 100,
        ),
      ];

  double _calculateLevelProgress(int donations) {
    if (donations >= 50) return 1.0;
    if (donations >= 25) return (donations - 25) / 25;
    if (donations >= 10) return (donations - 10) / 15;
    if (donations >= 5) return (donations - 5) / 5;
    if (donations >= 1) return (donations - 1) / 4;
    return donations / 1;
  }

  int? _getNextMilestone(int donations) {
    if (donations >= 50) return null;
    if (donations >= 25) return 50;
    if (donations >= 10) return 25;
    if (donations >= 5) return 10;
    if (donations >= 1) return 5;
    return 1;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? DarkModeColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (isDark ? DarkModeColors.darkOutline : LightModeColors.lightOutline)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: context.textStyles.headlineMedium?.bold,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textStyles.bodySmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final _Badge badge;
  final bool isEarned;
  final bool isDark;

  const _BadgeCard({
    required this.badge,
    required this.isEarned,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned
            ? (isDark ? DarkModeColors.darkPrimaryContainer : LightModeColors.lightPrimaryContainer)
            : (isDark ? DarkModeColors.darkSurfaceVariant : LightModeColors.lightSurfaceVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isEarned
              ? (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary)
                  .withValues(alpha: 0.5)
              : (isDark ? DarkModeColors.darkOutline : LightModeColors.lightOutline)
                  .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 36,
            color: isEarned
                ? (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary)
                : (isDark ? DarkModeColors.darkOutline : LightModeColors.lightOutline),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: context.textStyles.labelMedium?.semiBold,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: context.textStyles.labelSmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final _Milestone milestone;
  final bool isAchieved;
  final bool isDark;

  const _MilestoneCard({
    required this.milestone,
    required this.isAchieved,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkModeColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (isDark ? DarkModeColors.darkOutline : LightModeColors.lightOutline)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAchieved
                  ? (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary)
                  : (isDark ? DarkModeColors.darkOutline : LightModeColors.lightOutline)
                      .withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAchieved ? Icons.check_circle : Icons.lock,
              color: isAchieved ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: context.textStyles.titleMedium?.semiBold,
                ),
                const SizedBox(height: 4),
                Text(
                  milestone.subtitle,
                  style: context.textStyles.bodySmall?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${milestone.count}',
            style: context.textStyles.titleLarge?.bold.withColor(
              isAchieved
                  ? (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String id;
  final IconData icon;
  final String name;
  final String description;
  final int requiredDonations;

  const _Badge({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.requiredDonations,
  });
}

class _Milestone {
  final int count;
  final String title;
  final String subtitle;

  const _Milestone({
    required this.count,
    required this.title,
    required this.subtitle,
  });
}
