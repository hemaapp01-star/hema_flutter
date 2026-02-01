import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';

/// Help and Support page with FAQs and contact information
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1C1E), const Color(0xFF2D1B1B)]
                : [const Color(0xFFFFF5F5), const Color(0xFFFFEBEE)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Header with icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
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
                    child: const Icon(
                      Icons.help_outline,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'How Can We Help?',
                    style: context.textStyles.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Support Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contact Support',
                              style: context.textStyles.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Have a question or need assistance? Our support team is here to help!',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.mail,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'hello@hemadonation.com',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // FAQs Section
                Text(
                  'Frequently Asked Questions',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // FAQ Items
                const FAQItem(
                  question: 'What is Hema?',
                  answer:
                      'Hema is a blood donation matching platform that connects voluntary blood donors with healthcare providers in need. We help save lives by making it easier for donors and hospitals to find each other quickly.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'How does the donor matching work?',
                  answer:
                      'When a healthcare provider needs blood, they create a request specifying the blood type, units needed, and location. Available donors nearby with matching blood types are notified through push notifications. Donors can accept or decline based on their availability.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'Is my health information secure?',
                  answer:
                      'Yes! We take your privacy seriously. All health information is encrypted and stored securely. We only collect data necessary for blood donation matching (age, biological sex, weight, blood type, and location) and never share it without your consent.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'How do I mark myself as available?',
                  answer:
                      'On the donor home screen, use the "Availability Status" toggle to indicate when you\'re available to donate. When you toggle it on for the first time, you\'ll be asked to enable push notifications so you can be alerted when there\'s a need for blood near you.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'What happens when I accept a blood request?',
                  answer:
                      'When you accept a request, Hema will connect you with the healthcare provider through our chat interface. You\'ll receive the hospital\'s address and can get directions. The hospital will be notified that you\'re coming.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'Can I decline a blood donation request?',
                  answer:
                      'Absolutely! There\'s no obligation to accept any request. You can decline if you\'re not available, not feeling well, or for any other reason. Just let Hema know through the chat interface.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'How do I prepare for blood donation?',
                  answer:
                      'Before donating, drink plenty of water (at least 3 glasses), eat an iron-rich meal, get adequate sleep, and bring your national ID. Avoid fatty foods before donation and make sure you\'re feeling healthy.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'How do healthcare providers get verified?',
                  answer:
                      'Healthcare organizations must provide their official credentials and documentation during registration. Our team reviews each application to verify the legitimacy of the organization before approving their account.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'Can I delete my account?',
                  answer:
                      'Yes, you can delete your account at any time from the Profile tab. All your data will be permanently removed from our servers within 30 days of deletion.',
                ),
                const SizedBox(height: 12),
                const FAQItem(
                  question: 'Why do you need my location?',
                  answer:
                      'We use your location to match you with nearby healthcare providers. This ensures you\'re only notified about blood needs in your area. Your exact location is never shared with anyone - only your general proximity to healthcare facilities.',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// FAQ Item widget with expandable answer
class FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  bool _isExpanded = false;

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
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.answer,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
