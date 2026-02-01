import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';

/// Consent page that users must read and agree to before registration
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _hasAgreed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Terms and Consent', style: context.textStyles.titleLarge),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important Information',
                    style: context.textStyles.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    'About Hema',
                    'Hema is a matching service that connects people who need blood with willing donors. We facilitate communication between healthcare providers seeking blood donations and eligible donors in their area.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'Not Medical Advice',
                    'Hema does not provide medical advice, diagnosis, or treatment. All medical screening and final eligibility decisions are made by licensed healthcare providers.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'Healthcare Provider Responsibility',
                    'Healthcare providers using Hema are responsible for:\n\n• Verifying donor eligibility according to medical standards\n• Conducting appropriate health screenings\n• Following all applicable blood safety regulations\n• Ensuring proper medical supervision during donation',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'Donor Safety',
                    'If you are registering as a donor:\n\n• Always consult with healthcare professionals before donating\n• Provide accurate health information during screening\n• Follow all medical advice and guidelines\n• Report any adverse reactions immediately',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'Privacy and Data',
                    'By using Hema, you agree to our collection and use of your personal information as described in our Privacy Policy. Your health information is protected and shared only with relevant healthcare providers for donation coordination.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'No Guarantee',
                    'Hema does not guarantee:\n\n• Finding a match for blood requests\n• Availability of donors at any time\n• Specific outcomes or results\n• The medical suitability of any match',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    'Emergency Situations',
                    'Hema is not designed for emergency situations. In case of medical emergency, call emergency services immediately.',
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'By continuing, you acknowledge that you have read, understood, and agree to these terms and limitations.',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: isDark
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: isDark
                  ? DarkModeColors.darkSurfaceVariant
                  : LightModeColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _hasAgreed = !_hasAgreed),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _hasAgreed,
                          onChanged: (value) => setState(() => _hasAgreed = value ?? false),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I have read and understood the above information',
                          style: context.textStyles.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _hasAgreed ? () => context.push('/registration') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: _hasAgreed ? 2 : 0,
                    ),
                    child: Text(
                      'Continue to Registration',
                      style: context.textStyles.titleMedium?.copyWith(
                        color: _hasAgreed ? Colors.white : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
