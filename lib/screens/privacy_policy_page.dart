import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';

/// Privacy Policy page with detailed information about data collection and usage
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Privacy Policy', style: context.textStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Privacy Policy',
              style: context.textStyles.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: January 2026',
              style: context.textStyles.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Introduction',
              'Welcome to Hema ("we," "our," or "us"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our blood donation matching service.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '2. Information We Collect',
              'We collect several types of information to provide and improve our service:\n\n• Personal Information: Name, email address, phone number\n• Health Information: Date of birth, biological sex, weight, blood type\n• Location Information: Country, city, and neighborhood information\n• Account Information: Login credentials, user preferences\n• Usage Information: How you interact with our service',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '3. How We Use Your Information',
              'We use your information for the following purposes:\n\n• To match donors with blood donation requests from healthcare providers\n• To notify you of nearby donation opportunities\n• To verify your eligibility for blood donation\n• To improve and personalize our service\n• To communicate with you about your account and donations\n• To ensure the safety and security of our platform',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '4. Information Sharing',
              'We share your information only in the following circumstances:\n\n• With Healthcare Providers: When there is a compatible blood donation request, we share relevant information with verified healthcare providers\n• With Your Consent: We may share information when you explicitly consent\n• Legal Requirements: When required by law or to protect rights and safety\n• Service Providers: With trusted third-party service providers who assist in operating our service\n\nWe never sell your personal information to third parties for marketing purposes.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '5. Data Security',
              'We implement appropriate technical and organizational measures to protect your information:\n\n• Encryption of data in transit and at rest\n• Secure authentication and access controls\n• Regular security assessments and updates\n• Limited access to personal information by authorized personnel only\n\nHowever, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '6. Your Rights',
              'You have the following rights regarding your information:\n\n• Access: Request access to your personal information\n• Correction: Request correction of inaccurate information\n• Deletion: Request deletion of your account and data\n• Opt-Out: Opt out of donation notifications at any time\n• Data Portability: Request a copy of your data in a portable format\n• Withdraw Consent: Withdraw consent for data processing\n\nTo exercise these rights, please contact us using the information provided below.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '7. Data Retention',
              'We retain your personal information only as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required by law. When you delete your account, we will remove your personal information from our active systems within 30 days.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '8. Children\'s Privacy',
              'Our service is not intended for individuals under the age of 18. We do not knowingly collect personal information from children. If we become aware that we have collected information from a child, we will take steps to delete such information.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '9. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your country of residence. We ensure appropriate safeguards are in place to protect your information in accordance with this Privacy Policy.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '10. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new Privacy Policy on this page and updating the "Last Updated" date. Your continued use of the service after changes are posted constitutes acceptance of the updated Privacy Policy.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '11. Contact Us',
              'If you have questions or concerns about this Privacy Policy or our data practices, please contact us at:\n\nEmail: privacy@hemadonation.com\nAddress: 97 Ebitu Ukiwe St. Jabi, Abuja, Nigeria.\nPhone: +234 814 329 3156',
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: context.textStyles.bodyMedium?.copyWith(
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
