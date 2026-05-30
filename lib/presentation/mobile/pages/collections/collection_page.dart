// lib/presentation/mobile/pages/collections/collection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final myCollectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final res = await Supabase.instance.client
      .from('collections')
      .select(
          '*, loans(loan_number, borrower_name, total_payable, borrower_phone)')
      .eq('rider_id', uid)
      .order('collection_date', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(res);
});

final myActiveLoansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final res = await Supabase.instance.client
      .from('loans')
      .select()
      .eq('assigned_rider_id', uid)
      .inFilter('status', ['active', 'approved', 'overdue'])
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

class CollectionPage extends ConsumerStatefulWidget {
  final String collectionId;
  const CollectionPage({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Record'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RecordTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ── Record Tab ────────────────────────────────────────────────────────────────

class _RecordTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends ConsumerState<_RecordTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedLoanId;
  double _selectedLoanBalance = 0;
  String _status = 'collected';
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedLoanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a loan')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final amount = double.parse(_amountCtrl.text.trim());

      await Supabase.instance.client.from('collections').insert({
        'loan_id': _selectedLoanId,
        'rider_id': uid,
        'amount': amount,
        'status': _status,
        'collection_date':
            DateFormat('yyyy-MM-dd').format(_date),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(myCollectionsProvider);
      ref.invalidate(myActiveLoansProvider);

      _amountCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _selectedLoanId = null;
        _selectedLoanLabel = null;
        _selectedLoanBalance = 0;
        _date = DateTime.now();
        _status = 'collected';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Collection of ₱${NumberFormat('#,##0.00').format(amount)} recorded!'),
            backgroundColor: Colors.green,
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
    final loansAsync = ref.watch(myActiveLoansProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Record a Collection',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold))
              .animate()
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // Loan picker
          loansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (loans) => DropdownButtonFormField<String>(
              initialValue: _selectedLoanId,
              decoration: InputDecoration(
                labelText: 'Select Loan',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              hint: const Text('Choose a borrower loan...'),
              items: loans.map((l) {
                return DropdownMenuItem<String>(
                  value: l['id'] as String,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l['borrower_name'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14)),
                      Text(
                        'Loan #${l['loan_number'] ?? '-'} • ₱${NumberFormat('#,##0').format((l['total_payable'] as num?)?.toDouble() ?? 0)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) async {
                final l = loans.firstWhere((l) => l['id'] == v);
                // Compute outstanding balance
                final paid = await Supabase.instance.client
                    .from('collections')
                    .select('amount')
                    .eq('loan_id', v!);
                final totalPaid = (paid as List).fold<double>(
                    0,
                    (s, p) =>
                        s + ((p['amount'] as num?)?.toDouble() ?? 0));
                final totalPayable =
                    (l['total_payable'] as num?)?.toDouble() ?? 0;
                setState(() {
                  _selectedLoanId = v;
                  _selectedLoanBalance = totalPayable - totalPaid;
                });
              },
            ).animate().fadeIn(duration: 300.ms, delay: 50.ms),
          ),

          if (_selectedLoanId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Outstanding balance: ₱${NumberFormat('#,##0.00').format(_selectedLoanBalance)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount Collected (₱)',
              prefixIcon: const Icon(Icons.monetization_on_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount';
              if (_selectedLoanBalance > 0 && n > _selectedLoanBalance) {
                return 'Amount exceeds outstanding balance';
              }
              return null;
            },
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

          const SizedBox(height: 16),

          // Date
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Collection Date',
                  prefixIcon:
                      const Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                controller: TextEditingController(
                    text: DateFormat('MMMM d, yyyy').format(_date)),
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
            ),
          ),

          const SizedBox(height: 16),

          // Status
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: 'Collection Status',
              prefixIcon: const Icon(Icons.fact_check_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'collected', child: Text('Collected')),
              DropdownMenuItem(
                  value: 'partial', child: Text('Partial')),
              DropdownMenuItem(value: 'missed', child: Text('Missed')),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: const Icon(Icons.notes_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              alignLabelWithHint: true,
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 250.ms),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_outline),
              label: Text(_loading ? 'Recording...' : 'Record Collection',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colAsync = ref.watch(myCollectionsProvider);

    return colAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cols) {
        if (cols.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No collection history',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Group by date
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final c in cols) {
          final key = c['collection_date']?.toString().substring(0, 10) ?? '-';
          grouped.putIfAbsent(key, () => []).add(c);
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myCollectionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (ctx, i) {
              final date = grouped.keys.elementAt(i);
              final dayItems = grouped[date]!;
              final dayTotal = dayItems.fold<double>(
                  0,
                  (s, c) =>
                      s + ((c['amount'] as num?)?.toDouble() ?? 0));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmtGroupDate(date),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 13),
                        ),
                        Text(
                          '₱${NumberFormat('#,##0.00').format(dayTotal)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(ctx).colorScheme.primary,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ...dayItems.map((c) {
                    final amt =
                        (c['amount'] as num?)?.toDouble() ?? 0;
                    final status = c['status'] as String? ?? '-';
                    final statusColors = {
                      'collected': Colors.green,
                      'partial': Colors.orange,
                      'missed': Colors.red,
                    };
                    final sc =
                        statusColors[status] ?? Colors.grey;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              sc.withValues(alpha: 0.1),
                          child: Icon(Icons.payments_outlined,
                              color: sc),
                        ),
                        title: Text(
                            c['loans']?['borrower_name'] ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          'Loan #${c['loans']?['loan_number'] ?? '-'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${NumberFormat('#,##0.00').format(amt)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sc,
                                  fontSize: 14),
                            ),
                            Text(status.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: sc,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _fmtGroupDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('EEEE, MMMM d').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}