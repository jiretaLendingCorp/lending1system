// ============================================================
// FIX FILE: lib/presentation/web/pages/riders/riders_page.dart
// ============================================================
// BUGS FIXED:
//
// BUG 1 — PostgrestException: "Could not embed because more than one
//   relationship was found for 'users' and 'loans'"
//   ROOT CAUSE: .select('*, loans(count)') on the 'users' table is
//   ambiguous. The 'loans' table has FOUR FK columns pointing to 'users':
//   reviewed_by, approved_by, rejected_by, archived_by. PostgREST cannot
//   determine which FK to follow without an explicit hint.
//   FIX: Remove the loans(count) embed entirely. Query from the 'riders'
//   table instead and join to 'users' via the user_id FK.
//
// BUG 2 — .eq('role', 'rider') fails because the 'users' table has NO
//   'role' column. Role is stored in a separate 'roles' table, linked via
//   the 'role_id' FK. The DART model returned from auth_provider adds
//   'role' at runtime via RPC but the raw DB row does not have it.
//   FIX: Query from the 'riders' table (which already represents only
//   riders by definition) and join 'users!user_id(...)'.
//
// BUG 3 — Field name mismatches (users table schema vs page assumptions):
//   • 'full_name' → NOT a column; use first_name + last_name
//   • 'phone'     → NOT a column; use phone_number
//   • 'status'    → NOT a column; use account_status (active/suspended/…)
//   • 'area'      → NOT a column on riders; removed (not in schema)
//   FIX: All field accesses updated to match schema.sql exactly.
// ============================================================

// lib/presentation/web/pages/riders/riders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
// FIX: Query from 'riders' table (no role filter needed — only riders exist here)
//      Join with 'users' using the user_id FK.
//      Remove loans(count) — ambiguous FK relationship.
final ridersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('riders')
      .select(
        'id, rider_code, is_available, total_collections, total_amount_col, '
        'created_at, '
        'users!user_id(id, first_name, last_name, email, phone_number, account_status)',
      )
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final riderSearchProvider = StateProvider<String>((ref) => '');

// ── Helper: build full name from first/last ────────────────────────────────
String _fullName(Map<String, dynamic>? u) {
  if (u == null) return '-';
  final f = u['first_name'] as String? ?? '';
  final l = u['last_name'] as String? ?? '';
  return '$f $l'.trim().isEmpty ? '-' : '$f $l'.trim();
}

class RidersPage extends ConsumerWidget {
  const RidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridersAsync = ref.watch(ridersProvider);
    final search = ref.watch(riderSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riders',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Manage field collection riders',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Rider'),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search riders...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) =>
                  ref.read(riderSearchProvider.notifier).state = v,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            // Stats row
            ridersAsync.maybeWhen(
              data: (riders) => Row(
                children: [
                  _StatTile(
                    label: 'Total Riders',
                    value: riders.length.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Available',
                    value: riders
                        .where((r) => r['is_available'] == true)
                        .length
                        .toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Unavailable',
                    value: riders
                        .where((r) => r['is_available'] != true)
                        .length
                        .toString(),
                    icon: Icons.block,
                    color: Colors.orange,
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ridersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (riders) {
                  final filtered = riders.where((r) {
                    final u = r['users'] as Map<String, dynamic>?;
                    final q = '${_fullName(u)} ${u?['email'] ?? ''}'
                        .toLowerCase();
                    return q.contains(search.toLowerCase());
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No riders found',
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
                            DataColumn(label: Text('Rider')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Code')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((r) {
                            final u =
                                r['users'] as Map<String, dynamic>? ?? {};
                            // FIX: use account_status (not 'status')
                            final isActive =
                                (u['account_status'] ?? 'active') ==
                                    'active';
                            final name = _fullName(u);
                            return DataRow(cells: [
                              DataCell(Row(children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    name.isEmpty ? 'R' : name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.blue, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(name),
                              ])),
                              // FIX: email is on users sub-object
                              DataCell(Text(u['email'] ?? '-')),
                              // FIX: phone_number (not 'phone')
                              DataCell(Text(u['phone_number'] ?? '-')),
                              // FIX: use rider_code (schema has no 'area')
                              DataCell(Text(r['rider_code'] ?? '-')),
                              DataCell(
                                  _StatusBadge(active: isActive)),
                              DataCell(Row(children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () =>
                                      _showEditDialog(context, ref, r),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isActive
                                        ? Icons.block
                                        : Icons.check_circle_outline,
                                    size: 18,
                                    color: isActive
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  onPressed: () =>
                                      _toggleStatus(ref, r, isActive),
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

  // FIX: toggle account_status on the 'users' sub-table
  Future<void> _toggleStatus(
      WidgetRef ref, Map<String, dynamic> r, bool currentlyActive) async {
    final u = r['users'] as Map<String, dynamic>? ?? {};
    final userId = u['id'] as String?;
    if (userId == null) return;
    final newStatus = currentlyActive ? 'suspended' : 'active';
    await Supabase.instance.client
        .from('users')
        .update({'account_status': newStatus}).eq('id', userId);
    ref.invalidate(ridersProvider);
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) =>
          _RiderInfoDialog(onSaved: () => ref.invalidate(ridersProvider)),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (_) => _RiderInfoDialog(
          rider: r, onSaved: () => ref.invalidate(ridersProvider)),
    );
  }
}

// ── Add / Edit Dialog ─────────────────────────────────────────────────────────
// NOTE: Full rider creation requires many required fields (license, vehicle, etc.)
//       This dialog handles editing existing rider user info only.
//       New rider creation should go through the Employees page or a dedicated
//       admin-only onboarding flow that fills all required schema fields.

class _RiderInfoDialog extends StatefulWidget {
  final Map<String, dynamic>? rider;
  final VoidCallback onSaved;
  const _RiderInfoDialog({this.rider, required this.onSaved});

  @override
  State<_RiderInfoDialog> createState() => _RiderInfoDialogState();
}

class _RiderInfoDialogState extends State<_RiderInfoDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.rider?['users'] as Map<String, dynamic>? ?? {};
    _firstName = TextEditingController(text: u['first_name'] ?? '');
    _lastName = TextEditingController(text: u['last_name'] ?? '');
    _email = TextEditingController(text: u['email'] ?? '');
    _phone = TextEditingController(text: u['phone_number'] ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final u = widget.rider?['users'] as Map<String, dynamic>? ?? {};
      final userId = u['id'] as String?;
      if (userId == null) {
        throw Exception(
            'Cannot edit: user record not found. Use the Employees page to add new riders.');
      }
      await Supabase.instance.client.from('users').update({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone_number': _phone.text.trim(),
      }).eq('id', userId);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
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
    final isEdit = widget.rider != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Rider Info' : 'Add Rider'),
      content: Form(
        key: _key,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'New riders must be created through the Employees '
                      'management page (requires vehicle & license info).',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ),
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                readOnly: !isEdit,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                readOnly: !isEdit,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                readOnly: !isEdit,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        if (isEdit)
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
      ],
    );
  }
}

// ── Stat Tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.orange)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: active ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}