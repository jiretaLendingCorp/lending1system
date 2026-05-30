// lib/presentation/web/pages/settings/audit_logs_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final auditLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('audit_logs')
      .select('*, users(full_name, email, role)')
      .order('created_at', ascending: false)
      .limit(300);
  return List<Map<String, dynamic>>.from(res);
});

final auditSearchProvider = StateProvider<String>((ref) => '');
final auditActionFilterProvider = StateProvider<String>((ref) => 'all');

class AuditLogsPage extends ConsumerWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);
    final search = ref.watch(auditSearchProvider);
    final actionFilter = ref.watch(auditActionFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Audit Logs',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('System activity and user action history',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey)),
                ]),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: () => ref.invalidate(auditLogsProvider),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // Filters
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by user, action, or description...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) =>
                      ref.read(auditSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonFormField<String>(
                initialValue: actionFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Actions')),
                  DropdownMenuItem(value: 'login', child: Text('Login')),
                  DropdownMenuItem(value: 'logout', child: Text('Logout')),
                  DropdownMenuItem(
                      value: 'create', child: Text('Create')),
                  DropdownMenuItem(
                      value: 'update', child: Text('Update')),
                  DropdownMenuItem(
                      value: 'delete', child: Text('Delete')),
                  DropdownMenuItem(
                      value: 'approve', child: Text('Approve')),
                  DropdownMenuItem(
                      value: 'reject', child: Text('Reject')),
                ],
                onChanged: (v) =>
                    ref.read(auditActionFilterProvider.notifier).state = v!,
              ),
            ]).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            Expanded(
              child: logsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (logs) {
                  final filtered = logs.where((l) {
                    final q = '${l['users']?['full_name'] ?? ''} '
                            '${l['action'] ?? ''} '
                            '${l['description'] ?? ''}'
                        .toLowerCase();
                    final matchQ = q.contains(search.toLowerCase());
                    final matchA = actionFilter == 'all' ||
                        (l['action'] ?? '') == actionFilter;
                    return matchQ && matchA;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No audit logs found',
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
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Action')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('IP Address')),
                            DataColumn(label: Text('Timestamp')),
                          ],
                          rows: filtered.map((l) {
                            return DataRow(cells: [
                              DataCell(Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(l['users']?['full_name'] ?? '-',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(l['users']?['email'] ?? '-',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey)),
                                ],
                              )),
                              DataCell(Text(
                                  (l['users']?['role'] as String? ?? '-')
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(_ActionBadge(
                                  action: l['action'] ?? 'unknown')),
                              DataCell(ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 260),
                                child: Text(
                                  l['description'] ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                              DataCell(Text(l['ip_address'] ?? '-',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace'))),
                              DataCell(Text(
                                  _fmtDateTime(l['created_at']),
                                  style: const TextStyle(fontSize: 12))),
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

  String _fmtDateTime(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('MMM d, yyyy hh:mm a')
          .format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }
}

class _ActionBadge extends StatelessWidget {
  final String action;
  const _ActionBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    final map = {
      'login': Colors.blue,
      'logout': Colors.grey,
      'create': Colors.green,
      'update': Colors.orange,
      'delete': Colors.red,
      'approve': Colors.teal,
      'reject': Colors.deepOrange,
    };
    final c = map[action.toLowerCase()] ?? Colors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(action.toUpperCase(),
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}