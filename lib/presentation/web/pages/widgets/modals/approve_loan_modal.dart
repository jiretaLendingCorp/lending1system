// lib/presentation/web/pages/widgets/modals/approve_loan_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/constants/app_colors.dart';

class ApproveLoanModal extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onSuccess;
  const ApproveLoanModal({super.key, required this.loan, required this.onSuccess});

  @override
  State<ApproveLoanModal> createState() => _ApproveLoanModalState();
}

class _ApproveLoanModalState extends State<ApproveLoanModal> {
  bool   _loading = false;
  String _action  = 'approve';
  final  _remarkCtrl = TextEditingController();

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_action == 'reject' && _remarkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejection reason is required'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final sb     = Supabase.instance.client;
      final userId = sb.auth.currentUser?.id;

      // Get current user DB ID
      final actorRes = await sb.from('users').select('id').eq('auth_id', userId!).single();
      final actorId  = actorRes['id'] as String;

      final newStatus = _action == 'approve' ? 'approved' : 'rejected';
      final updateData = <String, dynamic>{
        'loan_status': newStatus,
        'updated_at':  DateTime.now().toIso8601String(),
      };

      if (_action == 'approve') {
        updateData['approved_by'] = actorId;
      } else {
        updateData['rejected_by']      = actorId;
        updateData['rejection_reason'] = _remarkCtrl.text.trim();
      }

      await sb.from('loans').update(updateData).eq('id', widget.loan['id']);

      // Notify lender
      await sb.functions.invoke('send-notification', body: {
        'recipient_id':      (widget.loan['lenders'] as Map)['user_id'],
        'notification_type': _action == 'approve' ? 'loan_approved' : 'loan_rejected',
        'title': _action == 'approve' ? '✅ Loan Approved!' : '❌ Loan Rejected',
        'body':  _action == 'approve'
            ? 'Your loan ${widget.loan['loan_code']} has been approved. Disbursement is being processed.'
            : 'Your loan ${widget.loan['loan_code']} was rejected. Reason: ${_remarkCtrl.text.trim()}',
        'data':  {'loan_id': widget.loan['id']},
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loan ${_action == 'approve' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: _action == 'approve' ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code   = widget.loan['loan_code'] as String? ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow:    AppColors.elevatedShadow,
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary100, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.gavel_rounded, color: AppColors.primary600, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan Decision', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(code, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary500, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),

            const SizedBox(height: 24),

            // Action toggle
            Container(
              decoration: BoxDecoration(
                color:        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _ToggleBtn(label: '✅  Approve', selected: _action == 'approve', color: AppColors.success, onTap: () => setState(() => _action = 'approve'))),
                  const SizedBox(width: 4),
                  Expanded(child: _ToggleBtn(label: '❌  Reject',  selected: _action == 'reject',  color: AppColors.error,   onTap: () => setState(() => _action = 'reject'))),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rejection reason
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _action == 'reject'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rejection Reason *', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller:  _remarkCtrl,
                          maxLines:    3,
                          decoration: const InputDecoration(hintText: 'Provide a clear reason for rejection…'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Loan summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Principal Amount', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                  Text(
                    '₱${(widget.loan['principal_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _action == 'approve' ? AppColors.success : AppColors.error,
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_action == 'approve' ? 'Approve Loan' : 'Reject Loan',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ).animate()
       .scale(begin: const Offset(0.88, 0.88), duration: 280.ms, curve: Curves.easeOutBack)
       .fadeIn(duration: 220.ms),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool   selected;
  final Color  color;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Assign CI Modal
// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/widgets/modals/assign_ci_modal.dart

class AssignCIModal extends StatefulWidget {
  final String       loanId;
  final String       loanCode;
  final VoidCallback onSuccess;
  const AssignCIModal({super.key, required this.loanId, required this.loanCode, required this.onSuccess});

  @override
  State<AssignCIModal> createState() => _AssignCIModalState();
}

class _AssignCIModalState extends State<AssignCIModal> {
  String?  _selectedRiderId;
  bool     _loading = false;
  bool     _loadingRiders = true;
  List<Map<String, dynamic>> _riders = [];
  String   _priority = 'normal';
  final    _instructCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  @override
  void dispose() {
    _instructCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRiders() async {
    final sb = Supabase.instance.client;
    final data = await sb
        .from('riders')
        .select('id, rider_code, is_available, users:user_id(first_name, last_name)')
        .eq('is_available', true)
        .eq('is_archived', false);

    if (mounted) setState(() { _riders = List<Map<String, dynamic>>.from(data); _loadingRiders = false; });
  }

  Future<void> _assign() async {
    if (_selectedRiderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rider'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final sb     = Supabase.instance.client;
      final userId = sb.auth.currentUser?.id;
      final actor  = await sb.from('users').select('id').eq('auth_id', userId!).single();

      // Create CI assignment
      await sb.from('ci_assignments').insert({
        'loan_id':      widget.loanId,
        'rider_id':     _selectedRiderId,
        'assigned_by':  actor['id'],
        'ci_status':    'assigned',
        'priority_level': _priority,
        'instructions': _instructCtrl.text.trim().isEmpty ? null : _instructCtrl.text.trim(),
      });

      // Update loan status
      await sb.from('loans').update({'loan_status': 'under_ci'}).eq('id', widget.loanId);

      // Notify rider
      final rider = _riders.firstWhere((r) => r['id'] == _selectedRiderId, orElse: () => {});
      final _ = rider['users'] as Map? ?? {};
      await sb.from('users').select('id').eq('id', _selectedRiderId!);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CI assigned successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow:    AppColors.elevatedShadow,
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delivery_dining_rounded, color: AppColors.accentDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign CI Rider', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(widget.loanCode, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary500, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),

            const SizedBox(height: 24),

            // Rider dropdown
            const Text('Select Available Rider *', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _loadingRiders
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    initialValue:      _selectedRiderId,
                    hint:       const Text('Choose a rider', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                    decoration: const InputDecoration(),
                    items: _riders.map((r) {
                      final u = r['users'] as Map? ?? {};
                      return DropdownMenuItem<String>(
                        value: r['id'] as String,
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 14, backgroundColor: AppColors.primary100,
                                child: Icon(Icons.person_rounded, size: 16, color: AppColors.primary600)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(r['rider_code'] as String? ?? '', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.primary500)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRiderId = v),
                    validator: (v) => v == null ? 'Please select a rider' : null,
                  ),

            const SizedBox(height: 16),

            // Priority
            const Text('Priority', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final p in ['normal', 'high', 'urgent'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: p != 'urgent' ? 8 : 0),
                      child: _ToggleBtn(
                        label:    p[0].toUpperCase() + p.substring(1),
                        selected: _priority == p,
                        color:    p == 'urgent' ? AppColors.error : p == 'high' ? AppColors.warning : AppColors.primary500,
                        onTap:    () => setState(() => _priority = p),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Instructions
            const Text('Instructions (Optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructCtrl,
              maxLines:   3,
              decoration: const InputDecoration(hintText: 'Special instructions for the rider…'),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _assign,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Assign Rider', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ).animate()
       .scale(begin: const Offset(0.88, 0.88), duration: 280.ms, curve: Curves.easeOutBack)
       .fadeIn(duration: 220.ms),
    );
  }
}