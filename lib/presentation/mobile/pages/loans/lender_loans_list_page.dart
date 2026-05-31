// lib/presentation/mobile/pages/loans/lender_loans_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/auth_provider.dart';

final _lenderLoansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final lender = await Supabase.instance.client
      .from('lenders').select('id').eq('user_id', userId).maybeSingle();
  if (lender == null) return [];

  return await Supabase.instance.client
      .from('loans')
      .select(
        'id, loan_code, principal_amount, outstanding_balance, total_payable, '
        'loan_status, payment_frequency, payment_amount, created_at, disbursed_at, '
        'loan_schedules(due_date, due_amount, is_paid, is_overdue)',
      )
      .eq('lender_id', lender['id'])
      .eq('is_archived', false)
      .order('created_at', ascending: false);
});

final _loanStatusFilterProvider = StateProvider<String>((ref) => 'all');

class LenderLoansListPage extends ConsumerWidget {
  const LenderLoansListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final async      = ref.watch(_lenderLoansProvider);
    final filter     = ref.watch(_loanStatusFilterProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Loans', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            onPressed: () => context.go(AppConstants.routeLenderApply),
            tooltip: 'Apply for Loan',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(current: filter),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(_lenderLoansProvider),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
                data: (loans) {
                  final filtered = filter == 'all'
                      ? loans
                      : loans.where((l) => l['loan_status'] == filter).toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(
                      filter: filter,
                      onApply: () => context.go(AppConstants.routeLenderApply),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount:    filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _LoanItem(loan: filtered[i])
                        .animate(delay: (60 * i).ms).fadeIn(duration: 350.ms).slideY(begin: 0.1),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final String current;
  const _FilterBar({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statuses = ['all', 'pending', 'active', 'overdue', 'completed'];

    return Container(
      height: 48,
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s       = statuses[i];
          final isActive= current == s;
          return GestureDetector(
            onTap: () => ref.read(_loanStatusFilterProvider.notifier).state = s,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color:        isActive ? AppColors.primary500 : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoanItem extends StatelessWidget {
  final Map<String, dynamic> loan;
  const _LoanItem({required this.loan});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final status      = loan['loan_status'] as String? ?? '';
    final statusColor = AppColors.loanStatusColor(status);
    final code        = loan['loan_code'] as String? ?? '';
    final principal   = (loan['principal_amount'] as num?)?.toDouble() ?? 0;
    final outstanding = (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
    final totalPay    = (loan['total_payable'] as num?)?.toDouble() ?? 0;
    final payAmt      = (loan['payment_amount'] as num?)?.toDouble() ?? 0;
    final freq        = loan['payment_frequency'] as String? ?? '';
    final progress    = totalPay > 0 ? (1 - (outstanding / totalPay)).clamp(0.0, 1.0) : 0.0;

    final createdAt   = loan['created_at'] as String? ?? '';
    String dateLabel  = '';
    if (createdAt.isNotEmpty) {
      try { dateLabel = 'Applied: ${DateFormat('MMM d, y').format(DateTime.parse(createdAt))}'; } catch (_) {}
    }

    final schedules = (loan['loan_schedules'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final nextDue   = schedules.where((s) => s['is_paid'] == false).toList()
      ..sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));
    final nextDueDate = nextDue.isNotEmpty ? nextDue.first['due_date'] as String? : null;

    return GestureDetector(
      onTap: () => context.go('/lender/loans/${loan['id']}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary500)),
                      Text('₱${_fmt(principal)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                  child: Text(_statusLabel(status), style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toStringAsFixed(0)}% paid',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('Balance: ₱${_fmt(outstanding)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:           progress,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? AppColors.success : AppColors.primary500),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _Chip(icon: Icons.repeat_rounded, label: '${_freqLabel(freq)} ₱${_fmt(payAmt)}'),
                if (nextDueDate != null) ...[
                  const SizedBox(width: 8),
                  _Chip(icon: Icons.calendar_today_rounded, label: _dueLabel(nextDueDate)),
                ],
                const Spacer(),
                if (status == 'active' || status == 'overdue')
                  TextButton(
                    onPressed: () => context.go('/lender/pay/${loan['id']}'),
                    style: TextButton.styleFrom(
                      padding:         const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Pay Now', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),

            if (dateLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(dateLabel, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _statusLabel(String s) {
    const map = {'pending': 'Pending', 'under_ci': 'Under CI', 'approved': 'Approved', 'rejected': 'Rejected', 'active': 'Active', 'overdue': 'Overdue', 'completed': 'Completed', 'frozen': 'Frozen'};
    return map[s] ?? s;
  }
  String _freqLabel(String f) => {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'}[f] ?? f;
  String _dueLabel(String due) {
    try { return 'Due: ${DateFormat('MMM d').format(DateTime.parse(due))}'; } catch (_) { return due; }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback onApply;
  const _EmptyState({required this.filter, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.lightTextSecondary),
          const SizedBox(height: 16),
          Text(
            filter == 'all' ? 'No loans yet' : 'No $filter loans',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (filter == 'all')
            ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Apply for a Loan', style: TextStyle(fontFamily: 'Poppins')),
            ),
        ],
      ),
    );
  }
}