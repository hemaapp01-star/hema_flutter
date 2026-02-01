import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';

/// Terms of Service page with detailed terms and conditions
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Terms of Service', style: context.textStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Terms of Service',
              style: context.textStyles.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: January 2025',
              style: context.textStyles.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Acceptance of Terms',
              'By accessing or using Hema ("the Service"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the Service. We reserve the right to modify these Terms at any time, and your continued use of the Service constitutes acceptance of any changes.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '2. Description of Service',
              'Hema is a blood donation matching platform that connects voluntary blood donors with healthcare providers who have blood donation needs. The Service provides:\n\n• Donor registration and profile management\n• Blood type and location-based matching\n• Notification system for donation opportunities\n• Communication tools between donors and healthcare providers\n• Donation tracking and history\n\nImportant: Hema is a matching service only. We do not provide medical advice, diagnosis, or treatment.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '3. User Eligibility',
              'To use this Service, you must:\n\n• Be at least 18 years old\n• Provide accurate and truthful information\n• Have the legal capacity to enter into binding contracts\n• Comply with all applicable laws and regulations\n• Not be prohibited from using the Service under applicable law\n\nFor donors specifically, you must meet standard blood donation eligibility requirements, which will be verified by healthcare providers.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '4. User Accounts',
              'When you create an account, you agree to:\n\n• Provide accurate, current, and complete information\n• Maintain and update your information to keep it accurate\n• Keep your password secure and confidential\n• Accept responsibility for all activities under your account\n• Notify us immediately of any unauthorized access\n• Not share your account with others\n\nWe reserve the right to suspend or terminate accounts that violate these Terms or for any other reason at our discretion.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '5. User Responsibilities',
              'As a user of Hema, you agree to:\n\n• Use the Service only for lawful purposes\n• Not misrepresent your identity or health information\n• Not use the Service to harm, harass, or defraud others\n• Not interfere with the proper functioning of the Service\n• Comply with all requests and instructions from healthcare providers\n• Report any safety concerns or adverse events\n• Respect the privacy and rights of other users',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '6. Healthcare Provider Verification',
              'Healthcare providers using the Service must:\n\n• Be licensed and in good standing\n• Provide valid credentials and documentation\n• Follow all applicable medical standards and regulations\n• Conduct appropriate donor screening and testing\n• Maintain medical supervision during donation procedures\n• Report any adverse events or safety concerns\n\nHema reserves the right to verify credentials and may suspend or terminate provider accounts that do not meet these requirements.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '7. Medical Disclaimer',
              'IMPORTANT MEDICAL DISCLAIMER:\n\n• Hema is NOT a medical service provider\n• We do not provide medical advice, diagnosis, or treatment\n• All medical decisions are made by licensed healthcare providers\n• Donors must undergo proper medical screening before donation\n• The Service does not replace professional medical judgment\n• We are not responsible for medical outcomes or complications\n\nAlways consult with qualified healthcare professionals regarding blood donation and any health concerns.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '8. Privacy and Data Protection',
              'Your use of the Service is also governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the Service, you consent to the collection, use, and sharing of your information as described in the Privacy Policy.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '9. Intellectual Property',
              'The Service, including all content, features, and functionality, is owned by Hema and is protected by copyright, trademark, and other intellectual property laws. You may not:\n\n• Copy, modify, or distribute our content without permission\n• Use our trademarks or branding without authorization\n• Reverse engineer or attempt to extract source code\n• Create derivative works based on the Service\n• Remove or alter any copyright or proprietary notices',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '10. Limitation of Liability',
              'TO THE FULLEST EXTENT PERMITTED BY LAW:\n\n• The Service is provided "AS IS" without warranties of any kind\n• We do not guarantee uninterrupted or error-free service\n• We are not liable for any indirect, incidental, or consequential damages\n• Our total liability shall not exceed the amount you paid to use the Service\n• We are not responsible for the actions of other users or healthcare providers\n• We are not liable for any medical outcomes or complications\n\nSome jurisdictions do not allow certain liability limitations, so some of these may not apply to you.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '11. Indemnification',
              'You agree to indemnify, defend, and hold harmless Hema and its officers, directors, employees, and agents from any claims, liabilities, damages, losses, or expenses arising from:\n\n• Your use of the Service\n• Your violation of these Terms\n• Your violation of any rights of another party\n• Your provision of inaccurate information',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '12. Termination',
              'We may terminate or suspend your access to the Service immediately, without prior notice, for any reason, including:\n\n• Breach of these Terms\n• Fraudulent or illegal activity\n• Misrepresentation of information\n• Harm to other users or the Service\n• At our sole discretion\n\nYou may terminate your account at any time by contacting us or using the account deletion feature in the app.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '13. Dispute Resolution',
              'Any disputes arising from these Terms or your use of the Service shall be resolved through:\n\n1. Good faith negotiation between the parties\n2. Binding arbitration if negotiation fails\n3. In accordance with the laws of [Jurisdiction]\n\nYou agree to waive any right to a jury trial or to participate in a class action lawsuit.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '14. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of [Jurisdiction], without regard to its conflict of law provisions. Any legal action or proceeding shall be brought exclusively in the courts of [Jurisdiction].',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '15. Changes to Terms',
              'We reserve the right to modify these Terms at any time. We will notify users of material changes by:\n\n• Posting the updated Terms on the Service\n• Updating the "Last Updated" date\n• Sending notification through the app or email\n\nYour continued use of the Service after changes are posted constitutes acceptance of the modified Terms.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '16. Severability',
              'If any provision of these Terms is found to be unenforceable or invalid, that provision shall be limited or eliminated to the minimum extent necessary, and the remaining provisions shall remain in full force and effect.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              '17. Contact Information',
              'If you have any questions about these Terms of Service, please contact us at:\n\nEmail: hello@hemadonation.com\nAddress: 97 Ebitu Ukiwe St. Jabi, Abuja, Nigeria.\nPhone: +234 814 329 3156',
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
