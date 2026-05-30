// lib/presentation/mobile/pages/ci/ci_report_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final myCiProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final res = await Supabase.instance.client
      .from('credit_investigations')
      .select(
          '*, loans(loan_number, borrower_name, amount, address, borrower_phone)')
      .eq('rider_id', uid)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final ciMobileFilterProvider = StateProvider<String>((ref) => 'all');

class CiReportPage extends ConsumerWidget {
  final String assignmentId;
  const CiReportPage({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciAsync = ref.watch(myCiProvider);
    final filter = ref.watch(ciMobileFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CI Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myCiProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'all',
                'pending',
                'ongoing',
                'completed',
                'failed',
              ].map((s) {
                final selected = filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == 'all' ? 'All' : _capitalize(s)),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(ciMobileFilterProvider.notifier).state = s,
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: ciAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                final filtered = filter == 'all'
                    ? items
                    : items
                        .where((i) => i['status'] == filter)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          filter == 'all'
                              ? 'No CI assignments yet'
                              : 'No $filter CI assignments',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myCiProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final ci = filtered[i];
                      return _CiCard(
                        ci: ci,
                        onUpdate: () =>
                            _showUpdateDialog(context, ref, ci),
                      ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 60));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _showUpdateDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> ci) {
    String selectedStatus = ci['status'] ?? 'pending';
    final notesCtrl = TextEditingController(text: ci['notes'] ?? '');
    final findings = TextEditingController(text: ci['findings'] ?? '');

    final loanNumber = ci['loans']?['loan_number'] as String? ?? '-';
    final borrowerName =
        ci['loans']?['borrower_name'] as String? ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Update CI Report',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Loan #$loanNumber • $borrowerName',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(
                      value: 'failed', child: Text('Failed')),
                ],
                onChanged: (v) => setState(() => selectedStatus = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: findings,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Findings',
                  hintText:
                      'Describe what you found during the visit...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Additional Notes',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    await Supabase.instance.client
                        .from('credit_investigations')
                        .update({
                      'status': selectedStatus,
                      'findings': findings.text.trim(),
                      'notes': notesCtrl.text.trim(),
                      if (selectedStatus == 'completed')
                        'completed_at':
                            DateTime.now().toIso8601String(),
                    }).eq('id', ci['id']);
                    ref.invalidate(myCiProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Submit Report',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CiCard extends StatelessWidget {
  final Map<String, dynamic> ci;
  final VoidCallback onUpdate;
  const _CiCard({required this.ci, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final status = ci['status'] as String? ?? 'pending';
    final statusColors = {
      'pending': Colors.orange,
      'ongoing': Colors.blue,
      'completed': Colors.green,
      'failed': Colors.red,
    };
    final color = statusColors[status] ?? Colors.grey;

    final amount =
        (ci['loans']?['amount'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  ci['loans']?['borrower_name'] ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.receipt_long, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Loan #${ci['loans']?['loan_number'] ?? '-'}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.monetization_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '₱${NumberFormat('#,##0.00').format(amount)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ]),
            if (ci['loans']?['address'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ci['loans']['address'] as String,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
            if (ci['loans']?['borrower_phone'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  ci['loans']['borrower_phone'] as String,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
              ]),
            ],
            if (ci['findings'] != null &&
                (ci['findings'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Findings: ${ci['findings']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Text(
                _fmtDate(ci['created_at']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              if (status != 'completed' && status != 'failed')
                TextButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Update'),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

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