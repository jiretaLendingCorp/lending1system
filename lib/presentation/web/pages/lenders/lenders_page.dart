// lib/presentation/web/pages/lenders/lenders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

final lendersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('users')
      .select()
      .eq('role', 'lender')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

final lenderSearchProvider = StateProvider<String>((ref) => '');

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
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    final q =
                        '${l['full_name'] ?? ''} ${l['email'] ?? ''}'
                            .toLowerCase();
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
                                  DataColumn(label: Text('Capital (₱)')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filtered.map((l) {
                                  final active =
                                      (l['status'] ?? 'active') == 'active';
                                  return DataRow(cells: [
                                    DataCell(Row(children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            Colors.purple.withValues(alpha: 0.1),
                                        child: Text(
                                          (l['full_name'] as String? ??
                                                  'L')[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.purple,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(l['full_name'] ?? '-'),
                                    ])),
                                    DataCell(Text(l['email'] ?? '-')),
                                    DataCell(Text(l['phone'] ?? '-')),
                                    DataCell(Text(
                                        '₱${_fmt(l['capital_amount'])}')),
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
                                          await Supabase.instance.client
                                              .from('users')
                                              .update({
                                            'status': active
                                                ? 'inactive'
                                                : 'active'
                                          }).eq('id', l['id']);
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

class _LenderDialog extends StatefulWidget {
  final Map<String, dynamic>? lender;
  final VoidCallback onSaved;
  const _LenderDialog({this.lender, required this.onSaved});

  @override
  State<_LenderDialog> createState() => _LenderDialogState();
}

class _LenderDialogState extends State<_LenderDialog> {
  final _key = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.lender?['full_name'] ?? '');
  late final _email =
      TextEditingController(text: widget.lender?['email'] ?? '');
  late final _phone =
      TextEditingController(text: widget.lender?['phone'] ?? '');
  late final _capital =
      TextEditingController(text: widget.lender?['capital_amount']?.toString() ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _capital.dispose();
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
        'capital_amount': double.tryParse(_capital.text.trim()) ?? 0,
        'role': 'lender',
      };
      if (widget.lender != null) {
        await Supabase.instance.client
            .from('users')
            .update(data)
            .eq('id', widget.lender!['id']);
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: 'Lender@1234',
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
    return AlertDialog(
      title: Text(widget.lender != null ? 'Edit Lender' : 'Add Lender'),
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
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  readOnly: widget.lender != null,
                  validator: (v) =>
                      v!.contains('@') ? null : 'Valid email required'),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _capital,
                  decoration:
                      const InputDecoration(labelText: 'Capital Amount (₱)'),
                  keyboardType: TextInputType.number),
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
              : Text(widget.lender != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

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