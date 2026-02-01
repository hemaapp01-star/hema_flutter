import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';

/// Page displaying standard donation procedures and information for donors
class DonationInfoPage extends StatelessWidget {
  const DonationInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Donation Information'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.info_outline,
              title: 'Blood Donation Overview',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              isDark: isDark,
              child: Text(
                'Blood donation is a simple, safe process that takes about 45-60 minutes from start to finish. Your donation can save up to three lives and helps patients with various medical conditions including trauma victims, surgical patients, and those with blood disorders.',
                style: context.textStyles.bodyMedium?.copyWith(
                  height: 1.6,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.checklist,
              title: 'Before You Donate',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BulletPoint('Eat a healthy meal and drink plenty of water', isDark),
                  _BulletPoint('Get a good night\'s sleep', isDark),
                  _BulletPoint('Bring a valid ID and your donor card (if you have one)', isDark),
                  _BulletPoint('Wear comfortable clothing with sleeves that can be raised', isDark),
                  _BulletPoint('Avoid alcohol 24 hours before donation', isDark),
                  _BulletPoint('Avoid fatty foods before donation', isDark),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.event_note,
              title: 'The Donation Process',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ProcessStep(
              number: 1,
              title: 'Registration',
              description: 'Check-in and provide identification and contact information.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ProcessStep(
              number: 2,
              title: 'Health Screening',
              description: 'A brief health questionnaire and mini-physical (blood pressure, temperature, pulse, hemoglobin check).',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ProcessStep(
              number: 3,
              title: 'Donation',
              description: 'The actual blood donation takes 8-10 minutes. You\'ll be seated comfortably while about 1 pint of blood is collected.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ProcessStep(
              number: 4,
              title: 'Refreshments',
              description: 'Rest for 10-15 minutes and enjoy snacks and drinks to replenish your body.',
              isDark: isDark,
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.self_improvement,
              title: 'After Donation',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BulletPoint('Drink extra fluids for the next 24-48 hours', isDark),
                  _BulletPoint('Avoid strenuous activity or heavy lifting for 5 hours', isDark),
                  _BulletPoint('Keep the bandage on for a few hours', isDark),
                  _BulletPoint('If you feel dizzy, lie down and elevate your feet', isDark),
                  _BulletPoint('Eat iron-rich foods to help replenish your blood', isDark),
                  _BulletPoint('Most donors can return to normal activities immediately', isDark),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.bloodtype,
              title: 'Types of Blood Components',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ComponentCard(
              title: 'Whole Blood',
              description: 'The most common type of donation. Can be separated into red cells, plasma, and platelets.',
              frequency: 'Every 56 days',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ComponentCard(
              title: 'Red Blood Cells',
              description: 'Carry oxygen throughout the body. Used for trauma patients and surgeries.',
              frequency: 'Every 112 days',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ComponentCard(
              title: 'Platelets',
              description: 'Help blood clot. Critical for cancer patients and surgical procedures.',
              frequency: 'Every 7 days (up to 24 times/year)',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ComponentCard(
              title: 'Plasma',
              description: 'The liquid portion of blood. Used for burn victims and trauma patients.',
              frequency: 'Every 28 days',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _ComponentCard(
              title: 'Cryoprecipitate',
              description: 'Rich in clotting factors. Used for bleeding disorders and trauma.',
              frequency: 'Derived from plasma',
              isDark: isDark,
            ),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.medical_services_outlined,
              title: 'Safety & Eligibility',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Requirements:',
                    style: context.textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint('At least 17 years old (16 with parental consent in some areas)', isDark),
                  _BulletPoint('Weigh at least 110 pounds', isDark),
                  _BulletPoint('Be in generally good health', isDark),
                  _BulletPoint('Not have donated blood in the last 56 days', isDark),
                  const SizedBox(height: 16),
                  Text(
                    'All blood is tested for safety and quality before use. Donating blood is safe and cannot transmit infections to you.',
                    style: context.textStyles.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _InfoCard(
              isDark: isDark,
              color: colorScheme.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Every donation makes a difference. Thank you for being a hero!',
                      style: context.textStyles.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          color: colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color? color;

  const _InfoCard({
    required this.child,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.grey[850] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final bool isDark;

  const _BulletPoint(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final bool isDark;

  const _ProcessStep({
    required this.number,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: context.textStyles.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.5,
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

class _ComponentCard extends StatelessWidget {
  final String title;
  final String description;
  final String frequency;
  final bool isDark;

  const _ComponentCard({
    required this.title,
    required this.description,
    required this.frequency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bloodtype,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Donate: $frequency',
              style: context.textStyles.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
