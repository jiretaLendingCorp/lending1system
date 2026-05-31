// lib/presentation/mobile/pages/ci/ci_report_page.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// BUG FIXES APPLIED:
//
// BUG 1 — Wrong table name (runtime: relation "credit_investigations" does not exist)
//   ORIGINAL: .from('credit_investigations')
//   FIX:      .from('ci_assignments')
//   The schema.sql defines the table as 'ci_assignments', not
//   'credit_investigations'. Every query hit a PostgREST 404 error.
//
// BUG 2 — Wrong column names in select (runtime: column does not exist)
//   ORIGINAL: 'loans(loan_number, borrower_name, amount, address, borrower_phone)'
//   FIX:      'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name, phone_number, addresses(street,barangay,municipality))))'
//   The loans table uses:
//     • loan_code  (not loan_number)
//     • no borrower_name column — borrower info lives on users table via lenders
//     • no amount column on loans for select purposes — principal_amount
//     • no address column — addresses is a separate table joined through users
//
// BUG 3 — Wrong rider_id comparison (runtime: returns no rows)
//   ORIGINAL: .eq('rider_id', uid)  where uid is the Supabase AUTH UUID
//   The ci_assignments.rider_id column references riders.id (app UUID),
//   NOT the Supabase auth UUID stored in auth.users.id.
//   FIX: Look up riders.id via users.auth_id first, then filter by that.
//
// BUG 4 — Wrong status column (runtime: column "status" does not exist)
//   ORIGINAL: used in filter UI as field 'status'
//   FIX:      field is 'ci_status'
//
// BUG 5 — No null-safety on nested join maps (runtime cast errors)
//   FIX: Added safe null-coalescing for all nested join fields.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

// ── Providers ─────────────────────────────────────────────────────────────

final myCiProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return [];

  final db = Supabase.instance.client;

  // BUG 3 FIX: Resolve auth UUID → users.id → riders.id
  final userRow = await db
      .from('users')
      .select('id')
      .eq('auth_id', authUid)
      .maybeSingle();

  if (userRow == null) return [];
  final userId = userRow['id'] as String;

  final riderRow = await db
      .from('riders')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

  if (riderRow == null) return [];
  final riderId = riderRow['id'] as String;

  // BUG 1 FIX: correct table 'ci_assignments'
  // BUG 2 FIX: correct column names and join path
  // BUG 3 FIX: filter by riders.id (app UUID)
  final res = await db
      .from('ci_assignments')
      .select(
        'id, ci_status, instructions, created_at, updated_at, '
        'loans!inner(loan_code, principal_amount, '
        '  lenders!inner('
        '    users!inner(first_name, last_name, phone_number, '
        '      addresses(street, barangay, municipality, province))'
        '  )'
        ')',
      )
      .eq('rider_id', riderId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(res);
});

// BUG 4 FIX: filter values use 'ci_status' values from schema
final ciMobileFilterProvider = StateProvider<String>((ref) => 'all');

// ─────────────────────────────────────────────────────────────────────────
// CI Report Page
// ─────────────────────────────────────────────────────────────────────────

class CiReportPage extends ConsumerWidget {
  final String assignmentId;
  const CiReportPage({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciAsync = ref.watch(myCiProvider);
    // BUG 4 FIX: filter key is 'ci_status'
    final filter = ref.watch(ciMobileFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Credit Investigations',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Filter Chips ──────────────────────────────────
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: filter == 'all',
                  onTap: () =>
                      ref.read(ciMobileFilterProvider.notifier).state = 'all',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  value: 'pending',
                  selected: filter == 'pending',
                  onTap: () => ref
                      .read(ciMobileFilterProvider.notifier)
                      .state = 'pending',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Ongoing',
                  value: 'ongoing',
                  selected: filter == 'ongoing',
                  onTap: () => ref
                      .read(ciMobileFilterProvider.notifier)
                      .state = 'ongoing',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Completed',
                  value: 'completed',
                  selected: filter == 'completed',
                  onTap: () => ref
                      .read(ciMobileFilterProvider.notifier)
                      .state = 'completed',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Failed',
                  value: 'failed',
                  selected: filter == 'failed',
                  onTap: () => ref
                      .read(ciMobileFilterProvider.notifier)
                      .state = 'failed',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── List ──────────────────────────────────────────
          Expanded(
            child: ciAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load CI assignments\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) {
                // BUG 4 FIX: filter on 'ci_status' field
                final filtered = filter == 'all'
                    ? list
                    : list
                        .where((ci) => ci['ci_status'] == filter)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          filter == 'all'
                              ? 'No CI assignments yet'
                              : 'No ${filter.toUpperCase()} assignments',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myCiProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _CiCard(ci: filtered[i])
                        .animate(delay: (60 * i).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CI Card
// ─────────────────────────────────────────────────────────────

class _CiCard extends StatelessWidget {
  final Map<String, dynamic> ci;
  const _CiCard({required this.ci});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // BUG 2 + 4 FIX: use correct field names
    final ciStatus = ci['ci_status'] as String? ?? 'pending';
    final instructions = ci['instructions'] as String? ?? '';
    final createdAt = DateTime.tryParse(ci['created_at'] ?? '');

    // Navigate nested join: loans → lenders → users → addresses
    final loan   = (ci['loans'] as Map?)?.cast<String, dynamic>() ?? {};
    final lender = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user   = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final addrList =
        (user['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final addr = addrList.isNotEmpty ? addrList.first : <String, dynamic>{};

    final loanCode   = loan['loan_code'] as String? ?? '-';
    final firstName  = user['first_name'] as String? ?? '';
    final lastName   = user['last_name']  as String? ?? '';
    final phone      = user['phone_number'] as String? ?? '';
    final borrowerName = '$firstName $lastName'.trim();
    final addressStr = [
      addr['street'],
      addr['barangay'],
      addr['municipality'],
      addr['province'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final statusColor = _statusColor(ciStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Loan: $loanCode',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  ciStatus.toUpperCase(),
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Address
          if (addressStr.isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    addressStr,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],

          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      instructions,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.infoDark),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Assigned: ${DateFormat('MMM d, yyyy').format(createdAt)}',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':   return AppColors.warning;
      case 'ongoing':   return AppColors.info;
      case 'completed': return AppColors.success;
      case 'failed':    return AppColors.error;
      default:          return AppColors.warning;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Filter Chip
// ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary500
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}