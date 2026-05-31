// lib/presentation/mobile/pages/history/lender_payment_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

final _lenderPaymentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final lender = await Supabase.instance.client
      .from('lenders')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  if (lender == null) return [];

  final lenderId = lender['id'] as String;

  final payments = await Supabase.instance.client
      .from('payments')
      .select(
        'id, payment_code, amount, payment_status, payment_method, '
        'collected_at, created_at, collected_by, '
        'loans(loan_code)',
      )
      .eq('lender_id', lenderId)
      .eq('is_archived', false)
      .order('created_at', ascending: false)
      .limit(100);

  final collectorIds = payments
      .where((p) => p['collected_by'] != null)
      .map((p) => p['collected_by'] as String)
      .toSet()
      .toList();

  final Map<String, String> collectorNames = {};
  if (collectorIds.isNotEmpty) {
    final riders = await Supabase.instance.client
        .from('riders')
        .select('id, users(first_name, last_name)')
        .inFilter('id', collectorIds);
    for (final r in riders) {
      final u = r['users'] as Map<String, dynamic>? ?? {};
      final name =
          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      collectorNames[r['id'] as String] = name.isEmpty ? 'Unknown' : name;
    }
  }

  return payments.map((p) {
    final collectorId = p['collected_by'] as String?;
    return {
      ...p,
      'collector_name':
          collectorId != null ? (collectorNames[collectorId] ?? '—') : '—',
    };
  }).toList();
});

class LenderPaymentHistoryPage extends ConsumerWidget {
  const LenderPaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final payments  = ref.watch(_lenderPaymentsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_lenderPaymentsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString(),
            onRetry: () => ref.invalidate(_lenderPaymentsProvider)),
        data: (list) {
          if (list.isEmpty) return const _EmptyView();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_lenderPaymentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: list.length,
              itemBuilder: (context, i) => _PaymentCard(
                payment: list[i],
                isDark: isDark,
              )
                  .animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool isDark;

  const _PaymentCard({required this.payment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt       = NumberFormat('#,##0.00', 'en_PH');
    final dateFmt   = DateFormat('MMM d, yyyy · h:mm a');
    final amount    = (payment['amount'] as num?)?.toDouble() ?? 0;
    final status    = payment['payment_status'] as String? ?? 'pending';
    final method    = payment['payment_method'] as String? ?? '';
    final code      = payment['payment_code'] as String? ?? '—';
    final collector = payment['collector_name'] as String? ?? '—';
    final loanCode  = (payment['loans'] as Map<String, dynamic>?)?['loan_code'] as String? ?? '—';
    final rawDate   = payment['collected_at'] ?? payment['created_at'];
    final date      = rawDate != null
        ? dateFmt.format(DateTime.parse(rawDate as String).toLocal())
        : '—';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon(status), color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '₱${fmt.format(amount)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          _InfoRow(
            icon: Icons.receipt_long_rounded,
            label: 'Loan',
            value: loanCode,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.person_pin_circle_rounded,
            label: 'Collected by',
            value: collector,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.payment_rounded,
            label: 'Method',
            value: _methodLabel(method),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: date,
          ),
        ]),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'verified':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.primary500;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'verified':
        return 'Verified';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return s;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'verified':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'failed':
        return Icons.cancel_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'gcash':
        return 'GCash';
      case 'maya':
        return 'Maya';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return m.isEmpty ? '—' : m;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 6),
      SizedBox(
        width: 90,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ]);
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        const Text(
          'No payments yet',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your payment history will appear here',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String      message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ]),
      ),
    );
  }
}