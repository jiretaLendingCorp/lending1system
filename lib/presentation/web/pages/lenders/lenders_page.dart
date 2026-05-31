// ============================================================
// FIX FILE: lib/presentation/web/pages/lenders/lenders_page.dart
// ============================================================
// BUG FIXED:
//
// PostgrestException: "column users.role does not exist" (code: 42703)
//
//   ROOT CAUSE: The original provider queried:
//     .from('users').select().eq('role', 'lender')
//   The 'users' table has NO 'role' column. Roles are stored in a
//   separate 'roles' table and linked via 'role_id' (UUID FK).
//   The 'role' string only appears at runtime after the RPC call in
//   auth_provider.dart, but is NOT stored on the users row.
//
//   FIX: Query from the 'lenders' table instead. The 'lenders' table
//   only contains lenders by definition. Join 'users!user_id(...)' to
//   get user profile data.
//
// ADDITIONAL FIELD FIXES:
//   • 'full_name'      → users has first_name + last_name (combined)
//   • 'phone'          → users has phone_number
//   • 'status'         → users has account_status
//   • 'capital_amount' → NOT in schema; use monthly_income from lenders
// ============================================================

// lib/presentation/web/pages/lenders/lenders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

// FIX: Query from 'lenders' (role-specific table), join with 'users'
final lendersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('lenders')
      .select(
        'id, lender_code, monthly_income, credit_score, risk_level, '
        'is_blacklisted, created_at, '
        'users!user_id(id, first_name, last_name, email, phone_number, account_status)',
      )
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final lenderSearchProvider = StateProvider<String>((ref) => '');

// ── Helper ────────────────────────────────────────────────────────────────────
String _fullName(Map<String, dynamic>? u) {
  if (u == null) return '-';
  final f = u['first_name'] as String? ?? '';
  final l = u['last_name'] as String? ?? '';
  return '$f $l'.trim().isEmpty ? '-' : '$f $l'.trim();
}

class LendersPage extends ConsumerWidget {
  const LendersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lendersProvider);
    final search = ref.watch(lenderSearchProvider);

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
                  Text('Lenders',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Manage lender accounts',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey)),
                ]),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showDialog(context, ref, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lender'),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search lenders...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) =>
                  ref.read(lenderSearchProvider.notifier).state = v,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (lenders) {
                  final filtered = lenders.where((l) {
                    final u = l['users'] as Map<String, dynamic>? ?? {};
                    final q =
                        '${_fullName(u)} ${u['email'] ?? ''}'.toLowerCase();
                    return q.contains(search.toLowerCase());
                  }).toList();

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text('No lenders found',
                                style: TextStyle(color: Colors.grey)),
                          ))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Phone')),
                                  // FIX: monthly_income instead of capital_amount
                                  DataColumn(
                                      label: Text('Monthly Income (₱)')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filtered.map((l) {
                                  final u = l['users'] as Map<String,
                                          dynamic>? ??
                                      {};
                                  // FIX: account_status (not 'status')
                                  final active =
                                      (u['account_status'] ?? 'active') ==
                                          'active';
                                  final name = _fullName(u);
                                  return DataRow(cells: [
                                    DataCell(Row(children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            Colors.purple.withValues(
                                                alpha: 0.1),
                                        child: Text(
                                          name.isEmpty
                                              ? 'L'
                                              : name[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.purple,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(name),
                                    ])),
                                    DataCell(Text(u['email'] ?? '-')),
                                    // FIX: phone_number (not 'phone')
                                    DataCell(Text(u['phone_number'] ?? '-')),
                                    // FIX: monthly_income from lenders row
                                    DataCell(Text(
                                        '₱${_fmt(l['monthly_income'])}')),
                                    DataCell(_Badge(active: active)),
                                    DataCell(Row(children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
                                        onPressed: () =>
                                            _showDialog(context, ref, l),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          active
                                              ? Icons.block
                                              : Icons.check_circle_outline,
                                          size: 18,
                                          color: active
                                              ? Colors.orange
                                              : Colors.green,
                                        ),
                                        onPressed: () async {
                                          final userId =
                                              u['id'] as String?;
                                          if (userId == null) return;
                                          // FIX: update account_status on users table
                                          await Supabase.instance.client
                                              .from('users')
                                              .update({
                                            'account_status': active
                                                ? 'suspended'
                                                : 'active'
                                          }).eq('id', userId);
                                          ref.invalidate(lendersProvider);
                                        },
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

  String _fmt(dynamic v) {
    if (v == null) return '0.00';
    return double.tryParse(v.toString())?.toStringAsFixed(2) ?? '0.00';
  }

  void _showDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? l) {
    showDialog(
      context: context,
      builder: (_) => _LenderDialog(
          lender: l, onSaved: () => ref.invalidate(lendersProvider)),
    );
  }
}

// ── Edit Dialog ───────────────────────────────────────────────────────────────
// NOTE: New lender creation requires many required fields (emergency contact,
//       income source, etc.) that should be handled via the mobile registration
//       flow. This dialog handles editing existing lender contact info only.

class _LenderDialog extends StatefulWidget {
  final Map<String, dynamic>? lender;
  final VoidCallback onSaved;
  const _LenderDialog({this.lender, required this.onSaved});

  @override
  State<_LenderDialog> createState() => _LenderDialogState();
}

class _LenderDialogState extends State<_LenderDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.lender?['users'] as Map<String, dynamic>? ?? {};
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
      final u = widget.lender?['users'] as Map<String, dynamic>? ?? {};
      final userId = u['id'] as String?;
      if (userId == null) {
        throw Exception('Cannot edit: user record not found.');
      }
      // FIX: update correct user fields
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
    final isEdit = widget.lender != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Lender' : 'Add Lender'),
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
                      'New lenders register via the mobile app. '
                      'Use this dialog only to edit existing lender contact info.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ),
              TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  readOnly: !isEdit),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  readOnly: !isEdit),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  readOnly: true),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  readOnly: !isEdit),
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

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final bool active;
  const _Badge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.orange)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(active ? 'ACTIVE' : 'INACTIVE',
          style: TextStyle(
            color:
                active ? Colors.green.shade700 : Colors.orange.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}