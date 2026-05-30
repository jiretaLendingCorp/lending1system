// lib/presentation/web/pages/ci/ci_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final ciProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('credit_investigations')
      .select('*, loans(loan_number, borrower_name, amount), users!rider_id(full_name)')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(res);
});

final ciStatusFilterProvider = StateProvider<String>((ref) => 'all');
final ciSearchProvider = StateProvider<String>((ref) => '');

class CiPage extends ConsumerWidget {
  const CiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciAsync = ref.watch(ciProvider);
    final statusFilter = ref.watch(ciStatusFilterProvider);
    final search = ref.watch(ciSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Credit Investigations',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Manage CI assignments and reports',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey)),
                ]),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // Summary
            ciAsync.maybeWhen(
              data: (items) {
                final pending =
                    items.where((i) => i['status'] == 'pending').length;
                final ongoing =
                    items.where((i) => i['status'] == 'ongoing').length;
                final completed =
                    items.where((i) => i['status'] == 'completed').length;
                final failed =
                    items.where((i) => i['status'] == 'failed').length;
                return Row(children: [
                  _CiCard('Pending', pending, Colors.orange, Icons.pending),
                  const SizedBox(width: 12),
                  _CiCard('Ongoing', ongoing, Colors.blue, Icons.search),
                  const SizedBox(width: 12),
                  _CiCard('Completed', completed, Colors.green,
                      Icons.check_circle),
                  const SizedBox(width: 12),
                  _CiCard('Failed', failed, Colors.red, Icons.cancel),
                ]).animate().fadeIn(duration: 300.ms, delay: 100.ms);
              },
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Filters
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by borrower or loan #...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) =>
                      ref.read(ciSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  filled: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(
                      value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                ],
                onChanged: (v) =>
                    ref.read(ciStatusFilterProvider.notifier).state = v!,
              ),
            ]).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: ciAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  final filtered = items.where((i) {
                    final q =
                        '${i['loans']?['borrower_name'] ?? ''} ${i['loans']?['loan_number'] ?? ''}'
                            .toLowerCase();
                    final matchQ = q.contains(search.toLowerCase());
                    final matchS = statusFilter == 'all' ||
                        (i['status'] ?? '') == statusFilter;
                    return matchQ && matchS;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No CI records found',
                            style: TextStyle(color: Colors.grey)));
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest),
                          columns: const [
                            DataColumn(label: Text('Loan #')),
                            DataColumn(label: Text('Borrower')),
                            DataColumn(label: Text('Assigned Rider')),
                            DataColumn(label: Text('Loan Amount')),
                            DataColumn(label: Text('Date Assigned')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((i) {
                            return DataRow(cells: [
                              DataCell(
                                  Text(i['loans']?['loan_number'] ?? '-')),
                              DataCell(Text(
                                  i['loans']?['borrower_name'] ?? '-')),
                              DataCell(
                                  Text(i['users']?['full_name'] ?? '-')),
                              DataCell(Text(
                                  '₱${_fmt(i['loans']?['amount'])}')),
                              DataCell(Text(_fmtDate(i['created_at']))),
                              DataCell(_CiStatusBadge(
                                  status: i['status'] ?? 'pending')),
                              DataCell(Row(children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility,
                                      size: 18),
                                  onPressed: () =>
                                      _showDetail(context, ref, i),
                                  tooltip: 'View Details',
                                ),
                                if ((i['status'] ?? '') == 'pending' ||
                                    (i['status'] ?? '') == 'ongoing')
                                  IconButton(
                                    icon: const Icon(Icons.update,
                                        size: 18, color: Colors.blue),
                                    onPressed: () =>
                                        _updateStatus(context, ref, i),
                                    tooltip: 'Update Status',
                                  ),
                              ])),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) =>
      (v == null ? 0.0 : (v as num).toDouble()).toStringAsFixed(2);

  String _fmtDate(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('MMM d, yyyy')
          .format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> ci) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CI Details'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Loan #', ci['loans']?['loan_number'] ?? '-'),
              _DetailRow('Borrower', ci['loans']?['borrower_name'] ?? '-'),
              _DetailRow('Assigned Rider', ci['users']?['full_name'] ?? '-'),
              _DetailRow('Status', (ci['status'] ?? '-').toUpperCase()),
              _DetailRow('Notes', ci['notes'] ?? 'No notes'),
              _DetailRow('Date Assigned', _fmtDate(ci['created_at'])),
              if (ci['completed_at'] != null)
                _DetailRow('Completed', _fmtDate(ci['completed_at'])),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _updateStatus(
      BuildContext context, WidgetRef ref, Map<String, dynamic> ci) {
    String selected = ci['status'] ?? 'pending';
    final noteCtrl = TextEditingController(text: ci['notes'] ?? '');
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Update CI Status'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Status'),
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
                  onChanged: (v) => setState(() => selected = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await Supabase.instance.client
                    .from('credit_investigations')
                    .update({
                  'status': selected,
                  'notes': noteCtrl.text.trim(),
                  if (selected == 'completed')
                    'completed_at': DateTime.now().toIso8601String(),
                }).eq('id', ci['id']);
                ref.invalidate(ciProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
          ],
        );
      }),
    );
  }
}

class _CiCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _CiCard(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _CiStatusBadge extends StatelessWidget {
  final String status;
  const _CiStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'pending': Colors.orange,
      'ongoing': Colors.blue,
      'completed': Colors.green,
      'failed': Colors.red,
    };
    final c = map[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: c.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}