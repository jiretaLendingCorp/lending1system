// lib/presentation/mobile/pages/assignments/rider_assignments_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

final _riderIdProvider = FutureProvider<String?>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final user = await Supabase.instance.client
      .from('users').select('id').eq('auth_id', uid).maybeSingle();
  if (user == null) return null;
  final rider = await Supabase.instance.client
      .from('riders').select('id').eq('user_id', user['id']).maybeSingle();
  return rider?['id'] as String?;
});

final riderCiAssignmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await ref.watch(_riderIdProvider.future);
  if (riderId == null) return [];
  return await Supabase.instance.client
      .from('ci_assignments')
      .select(
        'id, ci_status, instructions, created_at, '
        'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name, '
        'addresses(street, barangay, municipality))))',
      )
      .eq('rider_id', riderId)
      .order('created_at', ascending: false);
});

final riderCollectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await ref.watch(_riderIdProvider.future);
  if (riderId == null) return [];
  return await Supabase.instance.client
      .from('collections')
      .select(
        'id, collected_amount, collection_status, created_at, '
        'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name)))',
      )
      .eq('rider_id', riderId)
      .order('created_at', ascending: false)
      .limit(30);
});

class RiderAssignmentsPage extends ConsumerStatefulWidget {
  const RiderAssignmentsPage({super.key});
  @override ConsumerState<RiderAssignmentsPage> createState() => _RiderAssignmentsPageState();
}

class _RiderAssignmentsPageState extends ConsumerState<RiderAssignmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Assignments', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'CI Visits'),
            Tab(text: 'Collections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CiTab(onRefresh: () => ref.invalidate(riderCiAssignmentsProvider)),
          _CollectionsTab(onRefresh: () => ref.invalidate(riderCollectionsProvider)),
        ],
      ),
    );
  }
}

class _CiTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _CiTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderCiAssignmentsProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
        data: (items) => items.isEmpty
            ? const _EmptyState(icon: Icons.assignment_outlined, message: 'No CI assignments', sub: 'You have no pending CI visits')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount:    items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CiItem(ci: items[i])
                    .animate(delay: (50 * i).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1),
              ),
      ),
    );
  }
}

class _CiItem extends StatelessWidget {
  final Map<String, dynamic> ci;
  const _CiItem({required this.ci});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final loan     = ci['loans'] as Map<String, dynamic>? ?? {};
    final lender   = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user     = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final addrs    = (user['addresses'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final addr     = addrs.isNotEmpty ? addrs.first : <String,dynamic>{};
    final status   = ci['ci_status'] as String? ?? 'pending';

    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode     = loan['loan_code'] as String? ?? '-';
    final addressStr   = [addr['street'], addr['barangay'], addr['municipality']]
        .where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final statusColor = status == 'completed' ? AppColors.success
        : status == 'ongoing'   ? AppColors.primary500 : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.assignment_outlined, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(borrowerName.isEmpty ? 'Unknown' : borrowerName,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Loan $loanCode',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          if (addressStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text(addressStr, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
              ],
            ),
          ],
          if ((ci['instructions'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColors.infoLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(ci['instructions'] as String,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.infoDark)),
                  ),
                ],
              ),
            ),
          ],
          if (status != 'completed') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/rider/ci/${ci['id']}'),
                child: Text(status == 'ongoing' ? 'Continue CI Report' : 'Start CI Visit',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _CollectionsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderCollectionsProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
        data: (items) => items.isEmpty
            ? const _EmptyState(icon: Icons.payments_outlined, message: 'No collections yet', sub: 'Collections you record will appear here')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount:    items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CollectionItem(collection: items[i])
                    .animate(delay: (50 * i).ms).fadeIn(duration: 300.ms),
              ),
      ),
    );
  }
}

class _CollectionItem extends StatelessWidget {
  final Map<String, dynamic> collection;
  const _CollectionItem({required this.collection});

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final amt          = (collection['collected_amount'] as num?)?.toDouble() ?? 0;
    final status       = collection['collection_status'] as String? ?? '';
    final loan         = collection['loans'] as Map<String, dynamic>? ?? {};
    final lender       = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user         = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode     = loan['loan_code'] as String? ?? '-';
    final createdAt    = collection['created_at'] as String? ?? '';

    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try { dateLabel = DateFormat('MMM d, y h:mm a').format(DateTime.parse(createdAt)); } catch (_) {}
    }

    final statusColor = status == 'completed' ? AppColors.success
        : status == 'failed' ? AppColors.error : AppColors.primary500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(borrowerName.isEmpty ? 'Unknown' : borrowerName,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Loan $loanCode',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (dateLabel.isNotEmpty)
                  Text(dateLabel, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₱${NumberFormat('#,##0.00').format(amt)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message, sub;
  const _EmptyState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}