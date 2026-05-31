// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX 4 — lib/presentation/mobile/pages/payments/payment_page.dart       ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  BUG A — Wrong column in collections.select: 'amount'                   ║
// ║    Schema column is 'collected_amount', not 'amount'.                   ║
// ║    FIX: .select('collected_amount')  &  fold uses 'collected_amount'    ║
// ║                                                                          ║
// ║  BUG B — Wrong columns in collections.insert                            ║
// ║    'amount'          → 'collected_amount'                               ║
// ║    'status'          → 'collection_status'                              ║
// ║    'collection_date' → not in schema; removed (use created_at default)  ║
// ║    'notes'           → 'collection_notes'                               ║
// ║    'rider_id' = auth UID — must be riders.id (app UUID), not auth UUID  ║
// ║    collections also requires schedule_id, lender_id, collection_code    ║
// ║    FIX: Lookup rider record first; remove collection_date; fix cols      ║
// ║                                                                          ║
// ║  BUG C — Wrong loans.update column 'status'                             ║
// ║    Schema uses 'loan_status' (enum), not 'status'.                      ║
// ║    FIX: .update({'loan_status': 'completed'})                           ║
// ║                                                                          ║
// ║  BUG D — Wrong loan field references in UI                               ║
// ║    loan['loan_number']   → loan['loan_code']                            ║
// ║    loan['borrower_name'] → not in loans; from lenders→users join        ║
// ║    loan['status']        → loan['loan_status']                          ║
// ║                                                                          ║
// ║  BUG E — Hardcoded broken route '/mobile/loans'                         ║
// ║    FIX: AppConstants.routeLenderLoans                                   ║
// ║                                                                          ║
// ║  BUG F — Audit log uses auth UUID as user_id                            ║
// ║    audit_logs.user_id references users.id (app UUID), not auth UID      ║
// ║    FIX: Resolve auth_id → users.id first                                ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// lib/presentation/mobile/pages/payments/payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';

// ✅ FIX A: Select collected_amount (not 'amount')
final paymentLoanProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, loanId) async {
  // ✅ FIX D: Join lenders→users for borrower name
  final loan = await Supabase.instance.client
      .from('loans')
      .select(
        'id, loan_code, loan_status, total_payable, principal_amount, '
        'outstanding_balance, total_paid, payment_frequency, payment_amount, '
        'lenders!inner(id, users!inner(first_name, last_name))',
      )
      .eq('id', loanId)
      .maybeSingle();

  if (loan == null) return null;

  // ✅ FIX A: collected_amount not 'amount'
  final cols = await Supabase.instance.client
      .from('collections')
      .select('collected_amount')
      .eq('loan_id', loanId);

  final totalCollected = (cols as List).fold<double>(
      0, (s, c) => s + ((c['collected_amount'] as num?)?.toDouble() ?? 0));

  return {
    'loan':           Map<String, dynamic>.from(loan),
    'totalCollected': totalCollected,
  };
});

class PaymentPage extends ConsumerStatefulWidget {
  final String loanId;
  const PaymentPage({super.key, required this.loanId});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String   _paymentStatus = 'completed';
  DateTime _paymentDate   = DateTime.now();
  bool     _loading       = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(Map<String, dynamic> loan, double balance) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final supabase     = Supabase.instance.client;
      final authUid      = supabase.auth.currentUser?.id;
      final amount       = double.parse(_amountCtrl.text.trim());
      final totalPayable = (loan['total_payable'] as num?)?.toDouble() ?? 0;
      final prevCollected= ref
          .read(paymentLoanProvider(widget.loanId))
          .value?['totalCollected'] as double? ?? 0;
      final newTotal     = prevCollected + amount;

      // ✅ FIX B: Resolve auth_id → users.id → riders.id
      String? appUserId;
      String? riderId;
      if (authUid != null) {
        final userRow = await supabase
            .from('users')
            .select('id')
            .eq('auth_id', authUid)
            .maybeSingle();
        appUserId = userRow?['id'] as String?;

        if (appUserId != null) {
          final riderRow = await supabase
              .from('riders')
              .select('id')
              .eq('user_id', appUserId)
              .maybeSingle();
          riderId = riderRow?['id'] as String?;
        }
      }

      // ✅ FIX B: Get lender_id from the loan
      final lenderId = loan['lenders']?['id'] as String?;

      // ✅ FIX B: collections schema requires collection_code, schedule_id,
      //           lender_id, collected_amount, collection_status, collection_notes.
      //           No 'collection_date' column.
      //
      //   NOTE: schedule_id is required (NOT NULL). In a real flow the
      //   schedule_id should come from the specific loan_schedule being paid.
      //   Here we look up the first unpaid overdue schedule for the loan.
      //   Replace this lookup with the actual schedule selection if your UI
      //   allows the user to choose which instalment they're paying.
      final scheduleRow = await supabase
          .from('loan_schedules')
          .select('id')
          .eq('loan_id', widget.loanId)
          .eq('is_paid', false)
          .order('due_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (scheduleRow == null) {
        throw Exception('No unpaid schedule found for this loan. It may already be fully paid.');
      }

      final scheduleId = scheduleRow['id'] as String;

      // Generate a unique collection code
      final colCode = 'COL-${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('collections').insert({
        'collection_code':   colCode,
        'loan_id':           widget.loanId,
        'schedule_id':       scheduleId,
        if (lenderId != null) 'lender_id': lenderId,
        if (riderId  != null) 'rider_id':  riderId,
        // ✅ FIX B: correct column names
        'collected_amount':  amount,
        'target_amount':     amount,
        'collection_status': _paymentStatus,        // FIX B: was 'status'
        'collection_notes':  _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),               // FIX B: was 'notes'
        // No 'collection_date' — uses created_at default
      });

      // ✅ FIX C: 'loan_status' not 'status'
      if (newTotal >= totalPayable) {
        await supabase
            .from('loans')
            .update({'loan_status': 'completed'})   // FIX C
            .eq('id', widget.loanId);
      }

      // ✅ FIX F: audit log — use appUserId (app UUID), not authUid
      if (appUserId != null) {
        final loanCode = loan['loan_code'] as String? ?? widget.loanId; // FIX D
        await supabase.from('audit_logs').insert({
          'user_id':    appUserId,                   // FIX F
          'action':     'create',
          'table_name': 'collections',
          'description':
              'Recorded payment ₱${amount.toStringAsFixed(2)} for loan $loanCode',
        });
      }

      ref.invalidate(paymentLoanProvider(widget.loanId));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Payment Recorded!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '₱${NumberFormat('#,##0.00').format(amount)} has been recorded.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (newTotal >= totalPayable) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('🎉 Loan Fully Paid!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // ✅ FIX E: correct route constant
                    context.go(AppConstants.routeLenderLoans);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(paymentLoanProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Loan not found.'));
          }

          final loan           = data['loan'] as Map<String, dynamic>;
          final totalCollected = data['totalCollected'] as double;
          final totalPayable   = (loan['total_payable'] as num?)?.toDouble() ?? 0;
          final balance        = (totalPayable - totalCollected).clamp(0, double.infinity);

          // ✅ FIX D: borrower name from join
          final lenderUser  = (loan['lenders'] as Map<String, dynamic>?)?['users'] as Map<String, dynamic>? ?? {};
          final firstName   = lenderUser['first_name'] as String? ?? '';
          final lastName    = lenderUser['last_name']  as String? ?? '';
          final borrowerName= '$firstName $lastName'.trim();

          // ✅ FIX D: loan_code not loan_number; loan_status not status
          final loanCode   = loan['loan_code']   as String? ?? '-';
          final loanStatus = loan['loan_status'] as String? ?? 'active';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loan summary
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ FIX D
                                Text(borrowerName.isEmpty ? '-' : borrowerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                Text('Loan #$loanCode',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          // ✅ FIX D: loan_status not status
                          _StatusPill(status: loanStatus),
                        ]),
                        const Divider(height: 24),
                        Row(children: [
                          Expanded(child: _BalanceTile(label: 'Total Payable', value: totalPayable,   color: Colors.grey.shade600)),
                          Expanded(child: _BalanceTile(label: 'Collected',     value: totalCollected, color: Colors.green)),
                          Expanded(child: _BalanceTile(label: 'Balance',       value: balance.toDouble(), color: balance > 0 ? Colors.red : Colors.green)),
                        ]),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                Text('Payment Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))
                    .animate().fadeIn(duration: 300.ms, delay: 100.ms),

                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(children: [
                    // Amount
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Payment Amount (₱)',
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        helperText: 'Outstanding balance: ₱${NumberFormat('#,##0.00').format(balance)}',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        if (n > balance + 0.01) return 'Amount exceeds balance';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

                    const SizedBox(height: 16),

                    // Payment date (display only — not stored in collections)
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _paymentDate = d);
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Payment Date (reference only)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          controller: TextEditingController(
                            text: DateFormat('MMMM d, yyyy').format(_paymentDate),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _paymentStatus,
                      decoration: InputDecoration(
                        labelText: 'Collection Status',
                        prefixIcon: const Icon(Icons.fact_check_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'partial',   child: Text('Partial')),
                        DropdownMenuItem(value: 'failed',    child: Text('Failed')),
                      ],
                      onChanged: (v) => setState(() => _paymentStatus = v!),
                    ).animate().fadeIn(duration: 300.ms, delay: 250.ms),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        alignLabelWithHint: true,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _submit(loan, balance.toDouble()),
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.payment),
                        label: Text(
                          _loading ? 'Recording...' : 'Record Payment',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 350.ms),

                    const SizedBox(height: 24),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'active':    Colors.teal,
      'approved':  Colors.green,
      'overdue':   Colors.red,
      'completed': Colors.green,
      'pending':   Colors.orange,
      'frozen':    Colors.blueGrey,
    };
    final c = map[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  const _BalanceTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('₱${NumberFormat('#,##0').format(value)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}