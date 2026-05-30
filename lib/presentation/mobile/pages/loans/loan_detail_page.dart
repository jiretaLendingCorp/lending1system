// lib/presentation/mobile/pages/loans/loan_detail_page.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// BUG FIXES APPLIED:
//
// 1. UNUSED IMPORT (diagnostic warning)
//    REMOVED: import '../../../../core/constants/app_colors.dart';
//    It was imported but never referenced in this file.
//
// 2. WRONG NAVIGATION ROUTE (GoRouter 404 crash)
//    OLD: context.go('/mobile/payments/$loanId')
//    FIX: context.go('/lender/pay/$loanId')
//         The route '/mobile/payments/...' does not exist in app_router.dart.
//         The correct lender pay route is '/lender/pay/:loanId'.
//
// 3. WRONG TABLE JOIN (PostgREST runtime error — null borrower data)
//    OLD: .select('*, users!lender_id(full_name), users!rider_id(full_name)')
//         • loans.lender_id references lenders.id, NOT users.id — the join
//           was on the wrong foreign key.
//         • loans has no rider_id column.
//         • users has no full_name column (schema uses first_name + last_name).
//    FIX: .select('*, lenders!lender_id(user_id, users!user_id(first_name, last_name, phone_number))')
//         Then derive borrowerName / borrowerPhone from the nested map.
//
// 4. WRONG FIELD NAMES — loans table (runtime null values)
//    OLD  →  FIX
//    loan['status']          →  loan['loan_status']
//    loan['amount']          →  loan['principal_amount']
//    loan['loan_number']     →  loan['loan_code']
//    loan['interest_amount'] →  loan['total_interest']
//    loan['due_date']        →  loan['expected_end_at']
//    loan['borrower_name']   →  derived from lenders→users join
//    loan['borrower_phone']  →  derived from lenders→users join
//    co_borrower_* fields    →  removed (not in schema — co-borrower lives in
//                                a separate table; leave as TODO)
//
// 5. WRONG FIELD NAMES — payments query (runtime null values)
//    Payment history now comes from the `payments` table (correct) instead of
//    the `collections` table. Column fixes:
//    OLD (collections)       →  FIX (payments)
//    p['collection_date']    →  p['collected_at'] / p['created_at']
//    p['amount']             →  p['amount']  (payments table has amount ✓)
//    p['status']             →  p['payment_status']
//
// 6. WRONG STATUS VALUE in _StatusBanner
//    OLD: 'paid' key — not in loan_status_enum.
//    FIX: replaced with 'completed' which IS in the enum.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart'; // FIX 1: app_colors removed

// ─── Provider ────────────────────────────────────────────────

final loanDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, loanId) async {
  final db = Supabase.instance.client;

  // FIX 3: Correct join path — loans → lenders → users
  final loan = await db
      .from('loans')
      .select(
        '*, lenders!lender_id(user_id, users!user_id(first_name, last_name, phone_number))',
      )
      .eq('id', loanId)
      .single();

  // FIX 5: Payment history comes from the payments table, not collections.
  final payments = await db
      .from('payments')
      .select()
      .eq('loan_id', loanId)
      .order('created_at', ascending: false);

  return {
    'loan':     Map<String, dynamic>.from(loan),
    'payments': List<Map<String, dynamic>>.from(payments),
  };
});

// ─── Page ────────────────────────────────────────────────────

class LoanDetailPage extends ConsumerWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          asyncData.maybeWhen(
            data: (d) {
              // FIX 4: use loan_status
              final status = d['loan']['loan_status'] as String? ?? '';
              if (status == 'approved' || status == 'active') {
                return TextButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay'),
                  onPressed: () =>
                      // FIX 2: correct lender pay route
                      context.go(
                        AppConstants.routeLenderPay
                            .replaceAll(':loanId', loanId),
                      ),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final loan     = data['loan'] as Map<String, dynamic>;
          final payments = data['payments'] as List<Map<String, dynamic>>;

          // FIX 3: Extract borrower info from lenders→users join
          final lenderInfo  = loan['lenders'] as Map<String, dynamic>?;
          final userInfo    = lenderInfo?['users'] as Map<String, dynamic>?;
          final borrowerName  = userInfo != null
              ? '${userInfo['first_name'] ?? ''} ${userInfo['last_name'] ?? ''}'.trim()
              : '-';
          final borrowerPhone = userInfo?['phone_number'] as String? ?? '-';

          // FIX 4: Correct field names
          final principal  = (loan['principal_amount'] as num?)?.toDouble() ?? 0;
          final totalPayable = (loan['total_payable'] as num?)?.toDouble() ?? principal;
          final totalPaid  = payments.fold<double>(
              0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));
          final balance    = totalPayable - totalPaid;
          final pct        = totalPayable > 0
              ? (totalPaid / totalPayable).clamp(0.0, 1.0)
              : 0.0;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(loanDetailProvider(loanId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX 4/6: use loan_status
                  _StatusBanner(status: loan['loan_status'] as String? ?? 'pending')
                      .animate()
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: 16),

                  // Progress card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  // FIX 4: loan_code
                                  'Loan #${loan['loan_code'] ?? '-'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}% paid',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: _AmountTile(
                                      label: 'Total Payable',
                                      value: totalPayable,
                                      color: Colors.grey.shade700)),
                              Expanded(
                                  child: _AmountTile(
                                      label: 'Total Paid',
                                      value: totalPaid,
                                      color: Colors.green)),
                              Expanded(
                                  child: _AmountTile(
                                      label: 'Balance',
                                      value: balance,
                                      color: balance > 0
                                          ? Colors.red
                                          : Colors.green)),
                            ]),
                          ]),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                  const SizedBox(height: 16),

                  // Loan info
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Loan Information',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 14),
                            // FIX 3: borrowerName from join
                            _InfoRow('Borrower', borrowerName),
                            _InfoRow('Phone',    borrowerPhone),
                            _InfoRow('Purpose',  loan['purpose'] as String? ?? '-'),
                            // FIX 4: principal_amount
                            _InfoRow('Principal', '₱${_fmt(principal)}'),
                            _InfoRow('Interest Rate',
                                '${loan['interest_rate'] ?? 0}%'),
                            // FIX 4: total_interest
                            _InfoRow('Interest Amount',
                                '₱${_fmt(loan['total_interest'])}'),
                            _InfoRow('Term',
                                '${loan['term_days'] ?? 0} days'),
                            _InfoRow('Date Applied',
                                _fmtDate(loan['created_at'])),
                            if (loan['disbursed_at'] != null)
                              _InfoRow('Date Disbursed',
                                  _fmtDate(loan['disbursed_at'])),
                            // FIX 4: expected_end_at
                            if (loan['expected_end_at'] != null)
                              _InfoRow('Due Date',
                                  _fmtDate(loan['expected_end_at'])),
                          ]),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                  const SizedBox(height: 16),

                  // Payment history
                  Text('Payment History',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold))
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 300.ms),
                  const SizedBox(height: 10),

                  if (payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 36, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No payments yet',
                                  style: TextStyle(color: Colors.grey)),
                            ]),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 350.ms)
                  else
                    ...payments.asMap().entries.map((e) {
                      final p   = e.value;
                      final amt = (p['amount'] as num?)?.toDouble() ?? 0;
                      // FIX 5: use payment_status, collected_at/created_at
                      final payDate = p['collected_at'] ?? p['created_at'];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.1),
                            child: const Icon(Icons.check_circle_outline,
                                color: Colors.green),
                          ),
                          title: Text(
                            '₱${_fmt(amt)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                          subtitle: Text(
                              _fmtDate(payDate),
                              style: const TextStyle(fontSize: 12)),
                          trailing: _PaymentStatusBadge(
                              // FIX 5: payment_status
                              status: p['payment_status'] as String? ?? 'completed'),
                        ),
                      ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: 350 + e.key * 50));
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(dynamic v) =>
      NumberFormat('#,##0.00')
          .format((v == null ? 0.0 : (v as num).toDouble()));

  String _fmtDate(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('MMM d, yyyy')
          .format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    // FIX 6: replaced 'paid' with 'completed' to match loan_status_enum
    final map = {
      'pending':              (Colors.orange, Icons.pending_outlined,        'Pending Approval'),
      'under_ci':             (Colors.blue,   Icons.search,                  'Under Investigation'),
      'approved':             (Colors.green,  Icons.check_circle_outline,    'Approved'),
      'active':               (Colors.teal,   Icons.monetization_on_outlined,'Active'),
      'overdue':              (Colors.red,    Icons.warning_amber,           'Overdue'),
      'completed':            (Colors.green,  Icons.task_alt,                'Fully Paid'),  // FIX: was 'paid'
      'frozen':               (Colors.blueGrey, Icons.ac_unit,              'Frozen'),
      'rejected':             (Colors.red,    Icons.cancel_outlined,         'Rejected'),
    };
    final info  = map[status] ??
        (Colors.grey, Icons.info_outline, status.toUpperCase());
    final (color, icon, label) = info;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  const _AmountTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(
        '₱${NumberFormat('#,##0').format(value)}',
        style: TextStyle(
            fontWeight: FontWeight.bold, color: color, fontSize: 14),
      ),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final String status;
  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status == 'completed' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}