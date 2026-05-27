// lib/presentation/web/pages/widgets/modals/loan_detail_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/constants/app_colors.dart';
import '../status_badge.dart';

class LoanDetailModal extends StatelessWidget {
  final Map<String, dynamic> loan;
  const LoanDetailModal({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final lender    = loan['lenders'] as Map? ?? {};
    final user      = lender['users'] as Map? ?? {};
    final status    = loan['loan_status'] as String? ?? '';
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.elevatedShadow,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient:     AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loan['loan_code'] as String? ?? '', style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        StatusBadge(status: status, type: 'loan', light: true),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Borrower Info
                    _SectionTitle('Borrower Information'),
                    const SizedBox(height: 12),
                    _InfoGrid([
                      ('Name',  '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'),
                      ('Email', user['email'] as String? ?? ''),
                      ('Phone', user['phone_number'] as String? ?? ''),
                      ('Lender Code', lender['lender_code'] as String? ?? ''),
                    ]),

                    const Divider(height: 32),

                    // Loan Details
                    _SectionTitle('Loan Details'),
                    const SizedBox(height: 12),
                    _InfoGrid([
                      ('Principal',   '₱${_fmt((loan['principal_amount'] as num?)?.toDouble() ?? 0)}'),
                      ('Interest',    '${loan['interest_rate'] ?? 0}%'),
                      ('Total Interest', '₱${_fmt((loan['total_interest'] as num?)?.toDouble() ?? 0)}'),
                      ('Total Payable',  '₱${_fmt((loan['total_payable'] as num?)?.toDouble() ?? 0)}'),
                      ('Outstanding',    '₱${_fmt((loan['outstanding_balance'] as num?)?.toDouble() ?? 0)}'),
                      ('Paid Amount',    '₱${_fmt((loan['total_paid'] as num?)?.toDouble() ?? 0)}'),
                    ]),

                    const Divider(height: 32),

                    // Payment Schedule
                    _SectionTitle('Payment Schedule'),
                    const SizedBox(height: 12),
                    _InfoGrid([
                      ('Frequency',      _freqLabel(loan['payment_frequency'] as String? ?? '')),
                      ('Payment Amount', '₱${_fmt((loan['payment_amount'] as num?)?.toDouble() ?? 0)}'),
                      ('Term',           '${loan['term_days'] ?? 0} days'),
                      ('Processing Fee', '₱${_fmt((loan['processing_fee'] as num?)?.toDouble() ?? 0)}'),
                      ('Service Fee',    '₱${_fmt((loan['service_fee'] as num?)?.toDouble() ?? 0)}'),
                      ('CI Fee',         '₱${_fmt((loan['ci_fee'] as num?)?.toDouble() ?? 0)}'),
                    ]),

                    if ((loan['purpose'] as String?)?.isNotEmpty == true) ...[
                      const Divider(height: 32),
                      _SectionTitle('Loan Purpose'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(loan['purpose'] as String, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      ),
                    ],

                    if ((loan['remarks'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _SectionTitle('Remarks'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(loan['remarks'] as String, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().scale(begin: const Offset(0.9, 0.9), duration: 250.ms, curve: Curves.easeOutBack)
       .fadeIn(duration: 200.ms),
    );
  }

  String _fmt(double v) =>
      v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _freqLabel(String f) {
    switch (f) {
      case 'daily':   return 'Daily';
      case 'weekly':  return 'Weekly';
      case 'monthly': return 'Monthly';
      default:        return f;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary));
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _InfoGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items.map((item) => SizedBox(
        width: 290,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.$1, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(item.$2, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
    );
  }
}