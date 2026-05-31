// ============================================================
// FIX FILE: lib/presentation/web/pages/collections/collections_page.dart
// ============================================================
// BUGS FIXED:
//
// BUG 1 — PostgrestException: "Could not find a relationship between
//   'collections' and 'users' in the schema cache" (hint: rider_id)
//
//   ROOT CAUSE: The query used 'users!rider_id(full_name)'. However,
//   collections.rider_id is a FK to the 'riders' table — NOT to 'users'.
//   The schema is:  collections.rider_id → riders.id → users.user_id
//   PostgREST cannot find a direct FK from collections to users on the
//   rider_id column, so it throws PGRST200.
//
//   FIX: Use the correct join path:
//     riders!rider_id(users!user_id(first_name, last_name))
//
// BUG 2 — Field name mismatches (schema vs original code):
//   • 'loans.loan_number'   → 'loans.loan_code'   (schema column name)
//   • 'loans.borrower_name' → NOT in schema; name via lenders→users join
//   • 'c['amount']'         → 'c['collected_amount']' (schema column)
//   • 'c['status']'         → 'c['collection_status']' (schema column)
//   • 'c['collection_date']'→ 'c['completed_at']' (no collection_date col)
//   • Status filter values  → schema enum: pending/assigned/collecting/
//                             completed/failed  (not collected/partial/missed)
// ============================================================

// lib/presentation/web/pages/collections/collections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// FIX: Correct join path for rider name, correct loan fields
final collectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('collections')
      .select(
        'id, collection_code, collection_status, target_amount, '
        'collected_amount, assigned_at, completed_at, created_at, '
        // FIX: loan_code not loan_number; join to lenders→users for borrower name
        'loans!loan_id(loan_code, lenders!lender_id(users!user_id(first_name, last_name))), '
        // FIX: riders!rider_id → users!user_id (correct FK chain)
        'riders!rider_id(users!user_id(first_name, last_name))',
      )
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(res);
});

final colDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final colStatusFilterProvider = StateProvider<String>((ref) => 'all');

// ── Helper ────────────────────────────────────────────────────────────────────
String _fullName(Map<String, dynamic>? u) {
  if (u == null) return '-';
  final f = u['first_name'] as String? ?? '';
  final l = u['last_name'] as String? ?? '';
  return '$f $l'.trim().isEmpty ? '-' : '$f $l'.trim();
}

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
                // FIX: use collected_amount (not 'amount')
                final total = cols.fold<double>(
                    0,
                    (s, c) =>
                        s +
                        ((c['collected_amount'] as num?)?.toDouble() ?? 0));
                final todayCols = cols.where((c) {
                  // FIX: use completed_at (no collection_date column)
                  final d = c['completed_at'] ?? c['created_at'];
                  if (d == null) return false;
                  final dt = DateTime.tryParse(d.toString());
                  if (dt == null) return false;
                  final now = DateTime.now();
                  return dt.year == now.year &&
                      dt.month == now.month &&
                      dt.day == now.day;
                }).toList();
                final todayTotal = todayCols.fold<double>(
                    0,
                    (s, c) =>
                        s +
                        ((c['collected_amount'] as num?)?.toDouble() ?? 0));

                return Row(children: [
                  _SummaryCard(
                    label: 'Total Collected',
                    value: '₱${_fmt(total)}',
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    label: "Today's Collections",
                    value: '₱${_fmt(todayTotal)}',
                    icon: Icons.today,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    label: 'Records',
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
                  // FIX: Use correct collection_status enum values from schema
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                        value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'assigned', child: Text('Assigned')),
                    DropdownMenuItem(
                        value: 'collecting', child: Text('Collecting')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'failed', child: Text('Failed')),
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
                    // FIX: collection_status (not 'status')
                    final matchStatus = statusFilter == 'all' ||
                        (c['collection_status'] ?? '') == statusFilter;
                    bool matchDate = true;
                    if (dateFilter != null) {
                      // FIX: completed_at or created_at
                      final d = c['completed_at'] ?? c['created_at'];
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
                            DataColumn(label: Text('Loan Code')),
                            DataColumn(label: Text('Borrower')),
                            DataColumn(label: Text('Rider')),
                            DataColumn(label: Text('Collected (₱)')),
                            DataColumn(label: Text('Target (₱)')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: filtered.map((c) {
                            // FIX: loan_code (not loan_number)
                            final loanCode =
                                c['loans']?['loan_code'] ?? '-';
                            // FIX: borrower name from lenders→users join
                            final borrowerUser = c['loans']?['lenders']
                                ?['users'] as Map<String, dynamic>?;
                            final borrowerName = _fullName(borrowerUser);
                            // FIX: rider name from riders→users join
                            final riderUser = c['riders']?['users']
                                as Map<String, dynamic>?;
                            final riderName = _fullName(riderUser);
                            return DataRow(cells: [
                              DataCell(Text(loanCode)),
                              DataCell(Text(borrowerName)),
                              DataCell(Text(riderName)),
                              // FIX: collected_amount (not 'amount')
                              DataCell(
                                  Text('₱${_fmt(c['collected_amount'])}')),
                              DataCell(
                                  Text('₱${_fmt(c['target_amount'])}')),
                              // FIX: completed_at or created_at date
                              DataCell(Text(_fmtDate(
                                  c['completed_at'] ?? c['created_at']))),
                              // FIX: collection_status (not 'status')
                              DataCell(_CollectionStatusBadge(
                                  status:
                                      c['collection_status'] ?? 'pending')),
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

// ── Summary Card ──────────────────────────────────────────────────────────────

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
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
// FIX: Updated to use correct collection_status enum values from schema

class _CollectionStatusBadge extends StatelessWidget {
  final String status;
  const _CollectionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // FIX: Map schema enum values (pending/assigned/collecting/completed/failed)
    Color c;
    switch (status.toLowerCase()) {
      case 'completed':
        c = Colors.green;
        break;
      case 'collecting':
        c = Colors.blue;
        break;
      case 'assigned':
        c = Colors.orange;
        break;
      case 'failed':
        c = Colors.red;
        break;
      default: // pending
        c = Colors.grey;
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