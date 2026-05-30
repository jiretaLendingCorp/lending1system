// lib/presentation/mobile/pages/payments/payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final paymentLoanProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, loanId) async {
  final loan = await Supabase.instance.client
      .from('loans')
      .select()
      .eq('id', loanId)
      .single();

  final paid = await Supabase.instance.client
      .from('collections')
      .select('amount')
      .eq('loan_id', loanId);

  final totalPaid = (paid as List).fold<double>(
      0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));

  return {
    'loan': Map<String, dynamic>.from(loan),
    'totalPaid': totalPaid,
  };
});

class PaymentPage extends ConsumerStatefulWidget {
  final String loanId;
  const PaymentPage({super.key, required this.loanId});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentStatus = 'collected';
  DateTime _paymentDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(Map<String, dynamic> loan) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final amount = double.parse(_amountCtrl.text.trim());
      final totalPayable =
          (loan['total_payable'] as num?)?.toDouble() ?? 0;
      final totalPaidBefore = ref
          .read(paymentLoanProvider(widget.loanId))
          .value?['totalPaid'] as double? ?? 0;
      final newTotal = totalPaidBefore + amount;

      // Record collection
      await Supabase.instance.client.from('collections').insert({
        'loan_id': widget.loanId,
        'rider_id': uid,
        'amount': amount,
        'status': _paymentStatus,
        'collection_date':
            DateFormat('yyyy-MM-dd').format(_paymentDate),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update loan status if fully paid
      if (newTotal >= totalPayable) {
        await Supabase.instance.client
            .from('loans')
            .update({'status': 'paid'}).eq('id', widget.loanId);
      }

      // Audit log
      if (uid != null) {
        await Supabase.instance.client.from('audit_logs').insert({
          'user_id': uid,
          'action': 'create',
          'description':
              'Recorded payment ₱${amount.toStringAsFixed(2)} for loan ${loan['loan_number']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      ref.invalidate(paymentLoanProvider(widget.loanId));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Payment Recorded!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '₱${NumberFormat('#,##0.00').format(amount)} has been recorded.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (newTotal >= totalPayable) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('🎉 Loan Fully Paid!',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
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
                    context.go('/mobile/loans');
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final loan = data['loan'] as Map<String, dynamic>;
          final totalPaid = data['totalPaid'] as double;
          final totalPayable =
              (loan['total_payable'] as num?)?.toDouble() ?? 0;
          final balance = (totalPayable - totalPaid).clamp(0, double.infinity);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loan summary
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loan['borrower_name'] ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17),
                                  ),
                                  Text(
                                    'Loan #${loan['loan_number'] ?? '-'}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ]),
                          ),
                          _StatusPill(
                              status: loan['status'] ?? 'active'),
                        ]),
                        const Divider(height: 24),
                        Row(children: [
                          Expanded(
                              child: _BalanceTile(
                                  label: 'Total Payable',
                                  value: totalPayable,
                                  color: Colors.grey.shade600)),
                          Expanded(
                              child: _BalanceTile(
                                  label: 'Paid',
                                  value: totalPaid,
                                  color: Colors.green)),
                          Expanded(
                              child: _BalanceTile(
                                  label: 'Balance',
                                  value: balance.toDouble(),
                                  color: balance > 0
                                      ? Colors.red
                                      : Colors.green)),
                        ]),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                Text('Payment Details',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 100.ms),

                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(children: [
                    // Amount
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Payment Amount (₱)',
                        prefixIcon:
                            const Icon(Icons.monetization_on_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        helperText:
                            'Outstanding balance: ₱${NumberFormat('#,##0.00').format(balance)}',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return 'Enter a valid amount';
                        }
                        if (n > balance + 0.01) {
                          return 'Amount exceeds balance';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

                    const SizedBox(height: 16),

                    // Payment date
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
                            labelText: 'Payment Date',
                            prefixIcon:
                                const Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          controller: TextEditingController(
                              text: DateFormat('MMMM d, yyyy')
                                  .format(_paymentDate)),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _paymentStatus,
                      decoration: InputDecoration(
                        labelText: 'Payment Status',
                        prefixIcon:
                            const Icon(Icons.fact_check_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'collected',
                            child: Text('Collected')),
                        DropdownMenuItem(
                            value: 'partial', child: Text('Partial')),
                      ],
                      onChanged: (v) =>
                          setState(() => _paymentStatus = v!),
                    ).animate().fadeIn(duration: 300.ms, delay: 250.ms),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon:
                            const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        alignLabelWithHint: true,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _loading ? null : () => _submit(loan),
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.payment),
                        label: Text(
                          _loading
                              ? 'Recording...'
                              : 'Record Payment',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
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
      'active': Colors.teal,
      'approved': Colors.green,
      'overdue': Colors.red,
      'paid': Colors.green,
      'pending': Colors.orange,
    };
    final c = map[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _BalanceTile(
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
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}