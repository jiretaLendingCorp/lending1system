// lib/presentation/web/pages/riders/riders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

final ridersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('users')
      .select('*, loans(count)')
      .eq('role', 'rider')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final riderSearchProvider = StateProvider<String>((ref) => '');

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
                    label: 'Active',
                    value: riders
                        .where((r) => r['status'] == 'active')
                        .length
                        .toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Inactive',
                    value: riders
                        .where((r) => r['status'] != 'active')
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
                    final q =
                        '${r['full_name'] ?? ''} ${r['email'] ?? ''}'
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
                            DataColumn(label: Text('Area')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((r) {
                            final isActive =
                                (r['status'] ?? 'active') == 'active';
                            return DataRow(cells: [
                              DataCell(Row(children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    (r['full_name'] as String? ?? 'R')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.blue, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(r['full_name'] ?? '-'),
                              ])),
                              DataCell(Text(r['email'] ?? '-')),
                              DataCell(Text(r['phone'] ?? '-')),
                              DataCell(Text(r['area'] ?? '-')),
                              DataCell(_StatusBadge(
                                  active: isActive)),
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
                                  onPressed: () => _toggleStatus(ref, r),
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

  Future<void> _toggleStatus(WidgetRef ref, Map<String, dynamic> r) async {
    final newStatus =
        (r['status'] ?? 'active') == 'active' ? 'inactive' : 'active';
    await Supabase.instance.client
        .from('users')
        .update({'status': newStatus}).eq('id', r['id']);
    ref.invalidate(ridersProvider);
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) =>
          _RiderFormDialog(onSaved: () => ref.invalidate(ridersProvider)),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (_) => _RiderFormDialog(
          rider: r, onSaved: () => ref.invalidate(ridersProvider)),
    );
  }
}

class _RiderFormDialog extends StatefulWidget {
  final Map<String, dynamic>? rider;
  final VoidCallback onSaved;
  const _RiderFormDialog({this.rider, required this.onSaved});

  @override
  State<_RiderFormDialog> createState() => _RiderFormDialogState();
}

class _RiderFormDialogState extends State<_RiderFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.rider?['full_name'] ?? '');
  late final _email =
      TextEditingController(text: widget.rider?['email'] ?? '');
  late final _phone =
      TextEditingController(text: widget.rider?['phone'] ?? '');
  late final _area =
      TextEditingController(text: widget.rider?['area'] ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'area': _area.text.trim(),
        'role': 'rider',
      };
      if (widget.rider != null) {
        await Supabase.instance.client
            .from('users')
            .update(data)
            .eq('id', widget.rider!['id']);
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: 'Rider@1234',
          data: data,
        );
      }
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
      title: Text(isEdit ? 'Edit Rider' : 'Add Rider'),
      content: Form(
        key: _key,
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
                readOnly: isEdit,
                validator: (v) =>
                    v!.contains('@') ? null : 'Valid email required',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(
                    labelText: 'Area / Route Assignment'),
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