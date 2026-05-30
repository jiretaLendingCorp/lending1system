// lib/presentation/web/pages/widgets/modals/assign_ci_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

final _availableRidersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('users')
      .select()
      .eq('role', 'rider')
      .eq('status', 'active')
      .order('full_name');
  return List<Map<String, dynamic>>.from(res);
});

class AssignCiModal extends ConsumerStatefulWidget {
  final String loanId;
  final String? borrowerName;
  final String? loanNumber;
  final VoidCallback? onAssigned;

  const AssignCiModal({
    super.key,
    required this.loanId,
    this.borrowerName,
    this.loanNumber,
    this.onAssigned,
  });

  @override
  ConsumerState<AssignCiModal> createState() => _AssignCiModalState();
}

class _AssignCiModalState extends ConsumerState<AssignCiModal> {
  String? _selectedRiderId;
  String? _selectedRiderName;
  final _notes = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedRiderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rider')));
      return;
    }
    setState(() => _loading = true);
    try {
      // Create CI record
      await Supabase.instance.client.from('credit_investigations').insert({
        'loan_id': widget.loanId,
        'rider_id': _selectedRiderId,
        'status': 'pending',
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update loan status to under_investigation
      await Supabase.instance.client.from('loans').update({
        'status': 'under_investigation',
        'assigned_rider_id': _selectedRiderId,
      }).eq('id', widget.loanId);

      // Log audit
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client.from('audit_logs').insert({
          'user_id': uid,
          'action': 'create',
          'description':
              'Assigned CI for loan ${widget.loanNumber ?? widget.loanId} to rider $_selectedRiderName',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAssigned?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('CI assigned to $_selectedRiderName successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
    final ridersAsync = ref.watch(_availableRidersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.assignment_ind,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assign CI Rider',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (widget.borrowerName != null)
                  Text('Borrower: ${widget.borrowerName}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey)),
              ]),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]).animate().fadeIn(duration: 200.ms),

            const Divider(height: 24),

            // Loan info
            if (widget.loanNumber != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Loan #: ${widget.loanNumber}',
                      style: const TextStyle(fontSize: 13)),
                ]),
              ),

            const SizedBox(height: 16),

            // Rider selector
            Text('Select Rider',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            ridersAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Text('Error loading riders: $e',
                  style: const TextStyle(color: Colors.red)),
              data: (riders) {
                if (riders.isEmpty) {
                  return const Text('No active riders available.',
                      style: TextStyle(color: Colors.grey));
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedRiderId,
                  decoration: InputDecoration(
                    hintText: 'Choose a rider...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  items: riders.map((r) {
                    return DropdownMenuItem<String>(
                      value: r['id'] as String,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Colors.blue.withValues(alpha: 0.12),
                          child: Text(
                            (r['full_name'] as String? ?? 'R')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.blue, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(r['full_name'] ?? '-',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              if (r['area'] != null)
                                Text(r['area'],
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ]),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedRiderId = v;
                      _selectedRiderName = riders
                          .firstWhere((r) => r['id'] == v,
                              orElse: () => {})['full_name'] as String?;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Notes
            Text('Notes (Optional)',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Add instructions or additional details for the rider...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _assign,
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.assignment_turned_in, size: 18),
                label: Text(_loading ? 'Assigning...' : 'Assign CI'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}