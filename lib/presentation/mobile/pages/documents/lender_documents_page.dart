// lib/presentation/mobile/pages/documents/lender_documents_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

final lenderDocumentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final lender = await Supabase.instance.client
      .from('lenders').select('id').eq('user_id', userId).maybeSingle();
  if (lender == null) return [];

  return await Supabase.instance.client
      .from('lender_documents')
      .select('id, document_type, file_url, verified_at, rejection_reason, created_at, verification_status')
      .eq('lender_id', lender['id'])
      .order('created_at', ascending: false);
});

class LenderDocumentsPage extends ConsumerWidget {
  const LenderDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async  = ref.watch(lenderDocumentsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Documents', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(lenderDocumentsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _RequiredDocsHeader().animate().fadeIn(duration: 400.ms),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: async.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
                ),
                data: (docs) {
                  const reqTypes = _requiredDocTypes;
                  final submitted = {for (var d in docs) d['document_type'] as String: d};

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final type   = reqTypes[i];
                        final doc    = submitted[type['key']];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DocumentCard(
                            type:    type,
                            doc:     doc,
                            onUpload: () => _uploadDocument(context, ref, type['key'] as String),
                          ),
                        ).animate(delay: (60 * i).ms).fadeIn(duration: 350.ms).slideY(begin: 0.1);
                      },
                      childCount: reqTypes.length,
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

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref, String docType) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !context.mounted) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes    = await picked.readAsBytes();
      final ext      = picked.name.split('.').last;
      final fileName = '${userId}_${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('lender-documents')
          .uploadBinary(fileName, bytes);

      final fileUrl = Supabase.instance.client.storage
          .from('lender-documents').getPublicUrl(fileName);

      final lender = await Supabase.instance.client
          .from('lenders').select('id').eq('user_id', userId).maybeSingle();

      if (lender != null) {
        await Supabase.instance.client.from('lender_documents').upsert({
          'lender_id':           lender['id'],
          'document_type':       docType,
          'file_url':            fileUrl,
          'verification_status': 'pending',
        });
        ref.invalidate(lenderDocumentsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }

  static const List<Map<String, String>> _requiredDocTypes = [
    {'key': 'valid_id',          'label': 'Valid Government ID',       'desc': 'Passport, Driver\'s License, SSS, or UMID'},
    {'key': 'proof_of_income',   'label': 'Proof of Income',           'desc': 'Payslip, COE, or Income Tax Return'},
    {'key': 'proof_of_billing',  'label': 'Proof of Billing Address',  'desc': 'Utility bill dated within 3 months'},
    {'key': 'selfie_with_id',    'label': 'Selfie with Valid ID',      'desc': 'Clear photo holding your valid ID'},
    {'key': 'signature',         'label': 'Signature Specimen',        'desc': 'Signature on white paper'},
  ];
}

class _RequiredDocsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.infoLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documents Required', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.infoDark)),
                SizedBox(height: 4),
                Text(
                  'Upload all required documents to complete your loan application. Documents are verified by our team within 1-2 business days.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.infoDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, String>  type;
  final Map<String, dynamic>? doc;
  final VoidCallback onUpload;

  const _DocumentCard({required this.type, this.doc, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final verStatus   = doc?['verification_status'] as String? ?? 'not_submitted';
    final hasDoc      = doc != null;

    final statusInfo  = _statusInfo(verStatus, hasDoc);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo['borderColor'] as Color),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color:        (statusInfo['iconColor'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusInfo['icon'] as IconData, color: statusInfo['iconColor'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type['label']!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                Text(type['desc']!,  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        (statusInfo['iconColor'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo['label'] as String,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: statusInfo['iconColor'] as Color),
                  ),
                ),
                if (doc?['rejection_reason'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rejected: ${doc!['rejection_reason']}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        hasDoc ? AppColors.primary100 : AppColors.primary500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasDoc ? 'Replace' : 'Upload',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                  color: hasDoc ? AppColors.primary600 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusInfo(String status, bool hasDoc) {
    if (!hasDoc) return {'icon': Icons.upload_file_rounded, 'iconColor': AppColors.lightTextSecondary, 'label': 'NOT SUBMITTED', 'borderColor': AppColors.lightBorder};
    switch (status) {
      case 'verified':  return {'icon': Icons.check_circle_rounded,  'iconColor': AppColors.success, 'label': 'VERIFIED',  'borderColor': AppColors.success.withValues(alpha: 0.3)};
      case 'rejected':  return {'icon': Icons.cancel_rounded,        'iconColor': AppColors.error,   'label': 'REJECTED',  'borderColor': AppColors.error.withValues(alpha: 0.3)};
      default:          return {'icon': Icons.schedule_rounded,      'iconColor': AppColors.warning, 'label': 'PENDING',   'borderColor': AppColors.warning.withValues(alpha: 0.3)};
    }
  }
}