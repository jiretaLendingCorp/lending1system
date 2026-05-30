// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX 3 — lib/presentation/mobile/pages/loans/loan_detail_page.dart      ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  BUG A — .single() → PGRST116 runtime crash                             ║
// ║    The provider calls .single() on loans. If loanId is stale or         ║
// ║    mis-routed, 0 rows = PGRST116 crash.                                 ║
// ║    FIX: .maybeSingle() + null guard.                                    ║
// ║                                                                          ║
// ║  BUG B — Wrong join syntax / non-existent column 'full_name'            ║
// ║    users!lender_id(full_name) — 'full_name' doesn't exist.              ║
// ║    Schema has first_name + last_name on users table.                    ║
// ║    FIX: Join lenders!inner(users!inner(first_name, last_name)).         ║
// ║                                                                          ║
// ║  BUG C — Wrong column names used in UI                                  ║
// ║    loan['loan_number']  → loan['loan_code']   (schema column)           ║
// ║    loan['amount']       → loan['principal_amount']                       ║
// ║    loan['status']       → loan['loan_status']                            ║
// ║    loan['borrower_name'] etc → don't exist; come from lenders→users     ║
// ║                                                                          ║
// ║  BUG D — Wrong collection table columns                                  ║
// ║    collections has no 'amount' column → use 'collected_amount'           ║
// ║    collections has no 'collection_date' → use 'completed_at'/'created_at'║
// ║    collections has no 'status' → use 'collection_status'                ║
// ║                                                                          ║
// ║  BUG E — Hardcoded broken route '/mobile/payments/$loanId'              ║
// ║    This route doesn't exist. FIX: AppConstants.routeLenderPay           ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// lib/presentation/mobile/pages/loans/loan_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_colors.dart';

final loanDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, loanId) async {
  // ✅ FIX A: .maybeSingle() instead of .single() — avoids PGRST116
  // ✅ FIX B: Correct join — lenders!inner(users!inner(first_name, last_name))
  final loan = await Supabase.instance.client
      .from('loans')
      .select(
        'id, loan_code, principal_amount, total_payable, total_interest, '
        'interest_rate, term_days, payment_frequency, payment_amount, '
        'outstanding_balance, total_paid, loan_status, purpose, remarks, '
        'disbursed_at, due_start_at, expected_end_at, created_at, '
        'lenders!inner(users!inner(first_name, last_name, phone_number, '
        'addresses(street, barangay, municipality, province)))',
      )
      .eq('id', loanId)
      .maybeSingle();

  if (loan == null) return null;

  // ✅ FIX D: Correct collection columns — collected_amount, collection_status, no collection_date
  final collections = await Supabase.instance.client
      .from('collections')
      .select('id, collected_amount, collection_status, collection_notes, completed_at, created_at')
      .eq('loan_id', loanId)
      .order('created_at', ascending: false);

  return {
    'loan':        Map<String, dynamic>.from(loan),
    'collections': List<Map<String, dynamic>>.from(collections),
  };
});

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
              if (d == null) return const SizedBox.shrink();
              // ✅ FIX C: Use 'loan_status' not 'status'
              final status = d['loan']['loan_status'] as String? ?? '';
              if (status == 'active' || status == 'approved') {
                return TextButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay'),
                  // ✅ FIX E: Use AppConstants route constant
                  onPressed: () => context.go(
                    AppConstants.routeLenderPay.replaceAll(':loanId', loanId),
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
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Loan not found.'));
          }

          final loan        = data['loan'] as Map<String, dynamic>;
          final collections = data['collections'] as List<Map<String, dynamic>>;

          // ✅ FIX B & C: Extract borrower name from nested lenders→users join
          final lenderUser   = (loan['lenders'] as Map<String, dynamic>?)?['users'] as Map<String, dynamic>? ?? {};
          final borrowerFirst= lenderUser['first_name'] as String? ?? '';
          final borrowerLast = lenderUser['last_name']  as String? ?? '';
          final borrowerName = '$borrowerFirst $borrowerLast'.trim();
          final borrowerPhone= lenderUser['phone_number'] as String? ?? '-';

          final address       = lenderUser['addresses'] as Map<String, dynamic>?;
          final borrowerAddr  = address == null
              ? '-'
              : '${address['street'] ?? ''}, ${address['barangay'] ?? ''}, '
                '${address['municipality'] ?? ''}, ${address['province'] ?? ''}'
                  .replaceAll(RegExp(r'^[, ]+|[, ]+$'), '');

          // ✅ FIX C: Use correct column names
          final loanCode    = loan['loan_code']       as String? ?? '-';
          final principal   = (loan['principal_amount']   as num?)?.toDouble() ?? 0;
          final totalPayable= (loan['total_payable']       as num?)?.toDouble() ?? principal;
          final totalPaid   = (loan['total_paid']           as num?)?.toDouble() ?? 0;
          final outstanding = (loan['outstanding_balance']  as num?)?.toDouble() ?? 0;
          final loanStatus  = loan['loan_status']      as String? ?? 'pending';
          final pct         = totalPayable > 0
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
                  // Status banner
                  _StatusBanner(status: loanStatus)
                      .animate()
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: 16),

                  // Progress card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ✅ FIX C: loan_code not loan_number
                              Text(
                                'Loan #$loanCode',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}% paid',
                                style: TextStyle(
                                  color:      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
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
                            Expanded(child: _AmountTile(label: 'Total Payable', value: totalPayable, color: Colors.grey.shade700)),
                            Expanded(child: _AmountTile(label: 'Total Paid',    value: totalPaid,    color: Colors.green)),
                            Expanded(child: _AmountTile(label: 'Balance',       value: outstanding,  color: outstanding > 0 ? Colors.red : Colors.green)),
                          ]),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                  const SizedBox(height: 16),

                  // Loan info
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loan Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 14),
                          // ✅ FIX B: borrower info from joined users table
                          _InfoRow('Borrower',     borrowerName),
                          _InfoRow('Phone',        borrowerPhone),
                          _InfoRow('Address',      borrowerAddr),
                          _InfoRow('Purpose',      loan['purpose'] as String? ?? '-'),
                          _InfoRow('Principal',    '₱${_fmt(principal)}'),
                          _InfoRow('Interest Rate','${loan['interest_rate'] ?? 0}%'),
                          _InfoRow('Total Interest','₱${_fmt((loan['total_interest'] as num?)?.toDouble() ?? 0)}'),
                          _InfoRow('Term',         '${loan['term_days'] ?? 0} days'),
                          _InfoRow('Frequency',    _freqLabel(loan['payment_frequency'] as String? ?? '')),
                          _InfoRow('Payment Amt',  '₱${_fmt((loan['payment_amount'] as num?)?.toDouble() ?? 0)}'),
                          _InfoRow('Date Applied', _fmtDate(loan['created_at'])),
                          if (loan['disbursed_at'] != null)
                            _InfoRow('Disbursed At', _fmtDate(loan['disbursed_at'])),
                          if (loan['expected_end_at'] != null)
                            _InfoRow('Due Date', _fmtDate(loan['expected_end_at'])),
                          if (loan['remarks'] != null && (loan['remarks'] as String).isNotEmpty)
                            _InfoRow('Remarks', loan['remarks'] as String),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                  const SizedBox(height: 16),

                  // Collection history
                  Text(
                    'Collection History',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
                  const SizedBox(height: 10),

                  if (collections.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color:        Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No collections yet', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 350.ms)
                  else
                    ...collections.asMap().entries.map((e) {
                      final c   = e.value;
                      // ✅ FIX D: collected_amount not amount
                      final amt = (c['collected_amount'] as num?)?.toDouble() ?? 0;
                      // ✅ FIX D: collection_status not status; completed_at or created_at
                      final colStatus = c['collection_status'] as String? ?? '-';
                      final dateRaw   = c['completed_at'] ?? c['created_at'];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                            child: const Icon(Icons.check_circle_outline, color: Colors.green),
                          ),
                          title: Text(
                            '₱${_fmt(amt)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          subtitle: Text(_fmtDate(dateRaw), style: const TextStyle(fontSize: 12)),
                          trailing: _CollectionStatusBadge(status: colStatus),
                        ),
                      ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 350 + e.key * 50));
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

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  String _fmtDate(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }

  String _freqLabel(String f) {
    switch (f) {
      case 'daily':   return 'Daily';
      case 'weekly':  return 'Weekly';
      case 'monthly': return 'Monthly';
      default:        return f;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'pending':    (Colors.orange, Icons.pending_outlined,          'Pending Approval'),
      'under_ci':   (Colors.blue,   Icons.search,                    'Under Credit Investigation'),
      'approved':   (Colors.green,  Icons.check_circle_outline,      'Approved'),
      'active':     (Colors.teal,   Icons.monetization_on_outlined,  'Active'),
      'overdue':    (Colors.red,    Icons.warning_amber,             'Overdue'),
      'completed':  (Colors.green,  Icons.task_alt,                  'Completed'),
      'rejected':   (Colors.red,    Icons.cancel_outlined,           'Rejected'),
      'frozen':     (Colors.blueGrey, Icons.ac_unit,                 'Frozen'),
    };
    final info  = map[status] ?? (Colors.grey, Icons.info_outline, status.toUpperCase());
    final (color, icon, label) = info;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  const _AmountTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(
        '₱${NumberFormat('#,##0').format(value)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
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
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}

class _CollectionStatusBadge extends StatelessWidget {
  final String status;
  const _CollectionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = switch (status) {
      'completed' => Colors.green,
      'partial'   => Colors.orange,
      'failed'    => Colors.red,
      _           => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}