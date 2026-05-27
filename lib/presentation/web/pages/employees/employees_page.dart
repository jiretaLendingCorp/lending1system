// lib/presentation/web/pages/employees/employees_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final employeesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('users')
      .select()
      .eq('role', 'employee')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final empSearchProvider = StateProvider<String>((ref) => '');
final empStatusFilterProvider = StateProvider<String>((ref) => 'all');

// ─── Page ─────────────────────────────────────────────────────────────────────

class EmployeesPage extends ConsumerWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final search = ref.watch(empSearchProvider);
    final statusFilter = ref.watch(empStatusFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employees',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage employee accounts',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showAddEmployeeDialog(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Employee'),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),

            const SizedBox(height: 24),

            // ── Filters ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) =>
                        ref.read(empSearchProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonFormField<String>(
                  value: statusFilter,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) =>
                      ref.read(empStatusFilterProvider.notifier).state = v!,
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────────
            Expanded(
              child: employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (employees) {
                  final filtered = employees.where((e) {
                    final name =
                        '${e['full_name'] ?? ''} ${e['email'] ?? ''}'.toLowerCase();
                    final matchSearch = name.contains(search.toLowerCase());
                    final matchStatus = statusFilter == 'all' ||
                        (e['status'] ?? '') == statusFilter;
                    return matchSearch && matchStatus;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No employees found',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
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
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Joined')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered
                              .map((e) => _buildRow(context, ref, e))
                              .toList(),
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

  DataRow _buildRow(
      BuildContext context, WidgetRef ref, Map<String, dynamic> e) {
    final isActive = (e['status'] ?? 'active') == 'active';
    return DataRow(cells: [
      DataCell(Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            (e['full_name'] as String? ?? 'E')[0].toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(e['full_name'] ?? '-'),
      ])),
      DataCell(Text(e['email'] ?? '-')),
      DataCell(Text(e['phone'] ?? '-')),
      DataCell(_StatusChip(status: isActive ? 'active' : 'inactive')),
      DataCell(Text(_fmtDate(e['created_at']))),
      DataCell(Row(children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => _showEditDialog(context, ref, e),
          tooltip: 'Edit',
        ),
        IconButton(
          icon: Icon(
            isActive ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: isActive ? Colors.orange : Colors.green,
          ),
          onPressed: () => _toggleStatus(ref, e),
          tooltip: isActive ? 'Deactivate' : 'Activate',
        ),
      ])),
    ]);
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '-';
    try {
      return DateTime.parse(d.toString()).toLocal().toString().substring(0, 10);
    } catch (_) {
      return d.toString();
    }
  }

  Future<void> _toggleStatus(WidgetRef ref, Map<String, dynamic> e) async {
    final newStatus =
        (e['status'] ?? 'active') == 'active' ? 'inactive' : 'active';
    await Supabase.instance.client
        .from('users')
        .update({'status': newStatus}).eq('id', e['id']);
    ref.invalidate(employeesProvider);
  }

  void _showAddEmployeeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _EmployeeFormDialog(onSaved: () {
        ref.invalidate(employeesProvider);
      }),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> e) {
    showDialog(
      context: context,
      builder: (_) => _EmployeeFormDialog(
        employee: e,
        onSaved: () => ref.invalidate(employeesProvider),
      ),
    );
  }
}

// ─── Add/Edit Dialog ──────────────────────────────────────────────────────────

class _EmployeeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final VoidCallback onSaved;
  const _EmployeeFormDialog({this.employee, required this.onSaved});

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: widget.employee?['full_name'] as String? ?? '');
  late final _email = TextEditingController(
      text: widget.employee?['email'] as String? ?? '');
  late final _phone = TextEditingController(
      text: widget.employee?['phone'] as String? ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'role': 'employee',
      };
      if (widget.employee != null) {
        await Supabase.instance.client
            .from('users')
            .update(data)
            .eq('id', widget.employee!['id']);
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: 'Temp@1234',
          data: data,
        );
        await Supabase.instance.client.from('users').insert({
          ...data,
          'status': 'active',
        });
      }
      if (mounted) {
        Navigator.of(context).pop();
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
    final isEdit = widget.employee != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Employee' : 'Add Employee'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                readOnly: isEdit,
                validator: (v) =>
                    v!.contains('@') ? null : 'Valid email required',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.orange)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}