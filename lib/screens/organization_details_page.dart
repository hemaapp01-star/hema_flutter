import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:hema/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hema/models/user_model.dart';
import 'package:hema/models/healthcare_provider_model.dart';
import 'package:hema/models/blood_request_model.dart';
import 'package:hema/services/healthcare_provider_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hema/models/provider_verification_model.dart';

/// Organization Details or Matched Donors page
class OrganizationDetailsPage extends StatefulWidget {
  final BloodRequestModel? request;

  const OrganizationDetailsPage({super.key, this.request});

  @override
  State<OrganizationDetailsPage> createState() =>
      _OrganizationDetailsPageState();
}

class _OrganizationDetailsPageState extends State<OrganizationDetailsPage> {
  final HealthcareProviderService _providerService =
      HealthcareProviderService();
  String? _providerId;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProviderId();
  }

  Future<void> _loadProviderId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = UserModel.fromJson(userDoc.data()!);
        setState(() {
          _providerId = userData.providerId;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If request is provided, show matched donors page
    if (widget.request != null) {
      return _buildMatchedDonorsPage(isDark);
    }

    // Otherwise show organization details
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Organization Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_providerId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Organization Details'),
        ),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No Organization Found',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are not affiliated with any healthcare organization.',
                  style: context.textStyles.bodyMedium
                      ?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Details'),
      ),
      body: StreamBuilder<HealthcareProviderModel?>(
        stream: _providerService.getProviderStream(_providerId!),
        builder: (context, providerSnapshot) {
          if (providerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!providerSnapshot.hasData || providerSnapshot.data == null) {
            return Center(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Text(
                  'Organization not found',
                  style: context.textStyles.bodyLarge
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            );
          }

          final provider = providerSnapshot.data!;

          return SingleChildScrollView(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Organization Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            child: Icon(Icons.local_hospital,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _capitalizeWords(provider.organizationName),
                                  style:
                                      context.textStyles.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.providerType.displayName,
                                  style:
                                      context.textStyles.bodyMedium?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(
                          Icons.location_on, provider.address, isDark),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          Icons.location_city, provider.fullLocation, isDark),
                      if (provider.phoneNumber != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                            Icons.phone, provider.phoneNumber!, isDark),
                      ],
                      if (provider.email != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.email, provider.email!, isDark),
                      ],
                      const SizedBox(height: 20),
                      // Verification Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: provider.isVerified
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider.isVerified
                                  ? Icons.verified
                                  : Icons.schedule,
                              size: 16,
                              color: provider.isVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.isVerified
                                  ? 'Verified'
                                  : 'Pending Verification',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: provider.isVerified
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Upload License Button (if not verified)
                      if (!provider.isVerified) ...[
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading
                                ? null
                                : () => _uploadLicense(provider),
                            icon: _isUploading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.upload_file, size: 20),
                            label: Text(_isUploading
                                ? 'Uploading...'
                                : 'Upload Verification Document'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Affiliated Doctors Section
                Text(
                  'Affiliated Doctors',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                StreamBuilder<List<UserModel>>(
                  stream: _providerService.getAssociatedDoctors(_providerId!),
                  builder: (context, doctorsSnapshot) {
                    if (doctorsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final doctors = doctorsSnapshot.data ?? [];

                    if (doctors.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 60, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No Affiliated Doctors',
                                style: context.textStyles.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'There are no doctors associated with this organization yet.',
                                style: context.textStyles.bodyMedium
                                    ?.copyWith(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: doctors
                          .map((doctor) => _buildDoctorCard(doctor, isDark))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(UserModel doctor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person,
                size: 28, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.fullName,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.email,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  /// Build matched donors page when request is provided
  Widget _buildMatchedDonorsPage(bool isDark) {
    final request = widget.request!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Matched Donors'),
            Text(
              '${request.bloodGroup} - ${request.component.displayName}',
              style: context.textStyles.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
      body: request.matchedDonors.isEmpty
          ? Center(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No Matched Donors Yet',
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When donors accept this request, they will appear here.',
                      style: context.textStyles.bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<UserModel>>(
              stream: _getMatchedDonorsStream(request.matchedDonors),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Error loading matched donors: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Text(
                        'Error loading donors',
                        style: context.textStyles.bodyLarge
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                  );
                }

                final donors = snapshot.data ?? [];

                if (donors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Text(
                        'No donor information available',
                        style: context.textStyles.bodyLarge
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: donors.length,
                  itemBuilder: (context, index) =>
                      _buildDonorMatchCard(donors[index], isDark),
                );
              },
            ),
    );
  }

  /// Stream matched donors by their UIDs
  Stream<List<UserModel>> _getMatchedDonorsStream(List<String> donorIds) {
    if (donorIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore 'in' query supports max 10 items, so batch if needed
    return FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: donorIds.take(10).toList())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromJson(doc.data()))
            .toList());
  }

  /// Build donor match card with public details and contact button
  Widget _buildDonorMatchCard(UserModel donor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Donor header
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          donor.bloodType?.displayName ?? 'Unknown',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Donor details
          if (donor.city != null || donor.country != null) ...[
            _buildDetailRow(
              Icons.location_on,
              '${donor.city ?? ''}${donor.city != null && donor.country != null ? ', ' : ''}${donor.country ?? ''}',
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          if (donor.totalDonations != null) ...[
            _buildDetailRow(
              Icons.favorite,
              '${donor.totalDonations} donations',
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          if (donor.livesSaved != null) ...[
            _buildDetailRow(
              Icons.emoji_events,
              '${donor.livesSaved} lives saved',
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          if (donor.heroLevel != null) ...[
            _buildDetailRow(
              Icons.stars,
              donor.heroLevelName,
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          // Contact button
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _contactDonor(donor),
              icon: const Icon(Icons.phone, size: 20),
              label: const Text('Contact Donor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// Upload license document for verification
  Future<void> _uploadLicense(HealthcareProviderModel provider) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('Error: User is not authenticated');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication error. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('User authenticated: ${user.uid}');
      debugPrint('User email: ${user.email}');
      debugPrint('File selected: ${file.name}, size: ${file.size} bytes');

      setState(() => _isUploading = true);

      // Upload to Firebase Storage
      final fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final storagePath = 'provider_licenses/$fileName';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);



      // Determine content type from file extension
      final extension = file.extension?.toLowerCase();
      String contentType = 'application/octet-stream';
      if (extension == 'pdf') {
        contentType = 'application/pdf';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'png') {
        contentType = 'image/png';
      }
      
      debugPrint('Uploading file with content type: $contentType');
      final metadata = SettableMetadata(contentType: contentType);

      if (kIsWeb) {
        // On web, use bytes
        if (file.bytes == null) throw 'File bytes are null on web';
        await storageRef.putData(file.bytes!, metadata);
      } else {
        // On mobile, use file path
        if (file.path == null) throw 'File path is null on mobile';
        final ioFile = File(file.path!);
        await storageRef.putFile(ioFile, metadata);
      }
      final downloadUrl = await storageRef.getDownloadURL();

      // Create provider verification document
      final now = DateTime.now();
      final verificationId = FirebaseFirestore.instance
          .collection('provider_verification')
          .doc()
          .id;

      final verification = ProviderVerificationModel(
        id: verificationId,
        userId: user.uid,
        providerId: provider.id,
        organizationName: provider.organizationName,
        providerType: provider.providerType,
        licenseStoragePath: storagePath,
        licenseDownloadUrl: downloadUrl,
        status: VerificationStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await FirebaseFirestore.instance
          .collection('provider_verification')
          .doc(verificationId)
          .set(verification.toJson());

      // Update user document with license URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'licenseFileUrl': downloadUrl,
        'updatedAt': now,
      });

      debugPrint('License uploaded successfully: $downloadUrl');

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'License uploaded successfully! Your verification is pending.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading license: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Contact donor via phone or SMS
  Future<void> _contactDonor(UserModel donor) async {
    if (donor.phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available for this donor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show contact options dialog
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact ${donor.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call'),
              onTap: () => Navigator.of(context).pop('call'),
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send SMS'),
              onTap: () => Navigator.of(context).pop('sms'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    try {
      final phoneNumber = donor.phoneNumber!;
      final Uri uri = action == 'call'
          ? Uri.parse('tel:$phoneNumber')
          : Uri.parse('sms:$phoneNumber');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $action';
      }
    } catch (e) {
      debugPrint('Error contacting donor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $action donor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
