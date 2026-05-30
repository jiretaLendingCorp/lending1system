// lib/presentation/web/pages/collections/collections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final collectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('collections')
      .select('*, loans(loan_number, borrower_name), users!rider_id(full_name)')
      .order('collection_date', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(res);
});

final colDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final colStatusFilterProvider = StateProvider<String>((ref) => 'all');

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsProvider);
    final dateFilter = ref.watch(colDateFilterProvider);
    final statusFilter = ref.watch(colStatusFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text('Collections',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 4),
            Text('Daily collection records',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey))
                .animate()
                .fadeIn(duration: 300.ms, delay: 50.ms),

            const SizedBox(height: 24),

            // Summary cards
            async.maybeWhen(
              data: (cols) {
                final total = cols.fold<double>(
                    0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));
                final todayCols = cols.where((c) {
                  final d = c['collection_date'];
                  if (d == null) return false;
                  final dt = DateTime.tryParse(d.toString());
                  if (dt == null) return false;
                  final now = DateTime.now();
                  return dt.year == now.year &&
                      dt.month == now.month &&
                      dt.day == now.day;
                }).toList();
                final todayTotal = todayCols.fold<double>(
                    0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));

                return Row(children: [
                  _SummaryCard(
                    label: "Total Collected",
                    value: "₱${_fmt(total)}",
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    label: "Today's Collections",
                    value: "₱${_fmt(todayTotal)}",
                    icon: Icons.today,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    label: "Records",
                    value: cols.length.toString(),
                    icon: Icons.list_alt,
                    color: Colors.purple,
                  ),
                ]).animate().fadeIn(duration: 300.ms, delay: 100.ms);
              },
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Filters
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    labelText: 'Status',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                        value: 'collected', child: Text('Collected')),
                    DropdownMenuItem(
                        value: 'partial', child: Text('Partial')),
                    DropdownMenuItem(
                        value: 'missed', child: Text('Missed')),
                  ],
                  onChanged: (v) =>
                      ref.read(colStatusFilterProvider.notifier).state = v!,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dateFilter == null
                    ? 'Filter by Date'
                    : DateFormat('MMM d, yyyy').format(dateFilter)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: dateFilter ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  ref.read(colDateFilterProvider.notifier).state = d;
                },
              ),
              if (dateFilter != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      ref.read(colDateFilterProvider.notifier).state = null,
                  tooltip: 'Clear date filter',
                ),
              ],
            ]).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (cols) {
                  final filtered = cols.where((c) {
                    final matchStatus = statusFilter == 'all' ||
                        (c['status'] ?? '') == statusFilter;
                    bool matchDate = true;
                    if (dateFilter != null) {
                      final d = c['collection_date'];
                      if (d != null) {
                        final dt = DateTime.tryParse(d.toString());
                        if (dt != null) {
                          matchDate = dt.year == dateFilter.year &&
                              dt.month == dateFilter.month &&
                              dt.day == dateFilter.day;
                        }
                      }
                    }
                    return matchStatus && matchDate;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No collections found',
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
                                .surfaceContainerHighest,
                          ),
                          columns: const [
                            DataColumn(label: Text('Loan #')),
                            DataColumn(label: Text('Borrower')),
                            DataColumn(label: Text('Rider')),
                            DataColumn(label: Text('Amount (₱)')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: filtered.map((c) {
                            return DataRow(cells: [
                              DataCell(Text(
                                  c['loans']?['loan_number'] ?? '-')),
                              DataCell(Text(
                                  c['loans']?['borrower_name'] ?? '-')),
                              DataCell(Text(
                                  c['users']?['full_name'] ?? '-')),
                              DataCell(Text(
                                  '₱${_fmt(c['amount'])}')),
                              DataCell(
                                  Text(_fmtDate(c['collection_date']))),
                              DataCell(_CollectionStatusBadge(
                                  status: c['status'] ?? 'collected')),
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
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

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
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _CollectionStatusBadge extends StatelessWidget {
  final String status;
  const _CollectionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'collected':
        c = Colors.green;
        break;
      case 'partial':
        c = Colors.orange;
        break;
      default:
        c = Colors.red;
    }
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