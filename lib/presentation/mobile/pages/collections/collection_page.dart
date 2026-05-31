// lib/presentation/mobile/pages/collections/collection_page.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// BUG FIXES APPLIED:
//
// BUG 1 — Wrong column 'status' (runtime: column does not exist)
//   ORIGINAL: .inFilter('status', [...])
//   FIX:      .inFilter('loan_status', [...])   (loans table)
//             .inFilter('collection_status', [...])  (collections table)
//
// BUG 2 — Non-existent column 'collection_date' (runtime: column does not exist)
//   ORIGINAL: .order('collection_date', ascending: false)
//   Schema has no 'collection_date' column — use 'created_at' instead.
//   FIX:      .order('created_at', ascending: false)
//
// BUG 3 — Wrong column 'amount' in collections (runtime: column does not exist)
//   ORIGINAL: 'collections.amount'
//   FIX:      'collected_amount'
//
// BUG 4 — Wrong loan join columns (runtime: null borrower info)
//   ORIGINAL: 'loans(loan_number, borrower_name, total_payable, borrower_phone)'
//   Schema has no loan_number (it's loan_code), no borrower_name, no borrower_phone.
//   FIX: 'loans!inner(loan_code, total_payable, lenders!inner(users!inner(first_name,last_name,phone_number)))'
//
// BUG 5 — Wrong rider_id comparison (runtime: returns 0 rows)
//   ORIGINAL: .eq('rider_id', uid) where uid is the Supabase AUTH UUID
//   collections.rider_id references riders.id (app UUID), not auth UUID.
//   FIX: Resolve auth_id → users.id → riders.id first.
//
// BUG 6 — Wrong column 'assigned_rider_id' on loans (runtime: column does not exist)
//   ORIGINAL: .eq('assigned_rider_id', uid)
//   Schema has no 'assigned_rider_id' on loans.
//   FIX: Filter loans by lender_id via lenders.user_id resolved from auth_id.
//        (Show the lender's own loans that are active/overdue.)
//        Actually for a rider's "active loans to collect", the right filter
//        is collections with the rider_id whose collection_status is not completed.
//        Simplified: list loans that have pending collections assigned to this rider.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

// ── Helper — resolve auth UUID to rider app UUID ───────────────────────────

Future<String?> _resolveRiderId() async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return null;

  final db = Supabase.instance.client;
  final userRow = await db
      .from('users')
      .select('id')
      .eq('auth_id', authUid)
      .maybeSingle();
  if (userRow == null) return null;

  final riderRow = await db
      .from('riders')
      .select('id')
      .eq('user_id', userRow['id'] as String)
      .maybeSingle();

  return riderRow?['id'] as String?;
}

// ── Providers ──────────────────────────────────────────────────────────────

/// All collections assigned to this rider (most recent first)
final myCollectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await _resolveRiderId();
  if (riderId == null) return [];

  // BUG 1+2+3+4+5 FIX: correct column names, join path, and rider_id
  final res = await Supabase.instance.client
      .from('collections')
      .select(
        'id, collected_amount, collection_status, created_at, '
        'loans!inner(loan_code, total_payable, '
        '  lenders!inner(users!inner(first_name, last_name, phone_number)))',
      )
      .eq('rider_id', riderId) // BUG 5 FIX: riders.id app UUID
      .order('created_at', ascending: false) // BUG 2 FIX: was collection_date
      .limit(100);

  return List<Map<String, dynamic>>.from(res);
});

/// Active/overdue loans that have pending collections for this rider
final myActiveLoansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await _resolveRiderId();
  if (riderId == null) return [];

  // BUG 6 FIX: get loans through collections table (rider is assigned via collections)
  // Find loans that have collections assigned to this rider with pending/assigned status
  final collections = await Supabase.instance.client
      .from('collections')
      .select(
        'id, collection_status, collected_amount, '
        'loans!inner(id, loan_code, principal_amount, total_payable, '
        '  loan_status, outstanding_balance, '
        '  lenders!inner(users!inner(first_name, last_name, phone_number)))',
      )
      .eq('rider_id', riderId)
      .inFilter('collection_status', ['pending', 'assigned', 'collecting'])
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(collections);
});

// ─────────────────────────────────────────────────────────────────────────
// Collection Page
// ─────────────────────────────────────────────────────────────────────────

class CollectionPage extends ConsumerStatefulWidget {
  final String collectionId;
  const CollectionPage({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final collectionsAsync = ref.watch(myCollectionsProvider);
    final activeLoansAsync  = ref.watch(myActiveLoansProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Collections',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Pending / Active Collections ────────────────────
          activeLoansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(message: e.toString()),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyView(
                  icon: Icons.check_circle_outline,
                  message: 'No pending collections',
                  sub: 'All caught up!',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myActiveLoansProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _PendingCollectionCard(item: items[i])
                          .animate(delay: (60 * i).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.1),
                ),
              );
            },
          ),

          // ── Collection History ──────────────────────────────
          collectionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(message: e.toString()),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyView(
                  icon: Icons.history,
                  message: 'No collection history',
                  sub: 'Completed collections will appear here',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myCollectionsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _CollectionHistoryCard(collection: items[i])
                          .animate(delay: (50 * i).ms)
                          .fadeIn(duration: 250.ms),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pending Collection Card
// ─────────────────────────────────────────────────────────────────────────

class _PendingCollectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PendingCollectionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final loan     = (item['loans'] as Map?)?.cast<String, dynamic>() ?? {};
    final lender   = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user     = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};

    final loanCode      = loan['loan_code'] as String? ?? '-';
    final firstName     = user['first_name'] as String? ?? '';
    final lastName      = user['last_name']  as String? ?? '';
    final phone         = user['phone_number'] as String? ?? '';
    final borrowerName  = '$firstName $lastName'.trim();
    // BUG 3 FIX: 'collected_amount' (not 'amount')
    final collectedAmt  = (item['collected_amount'] as num?)?.toDouble() ?? 0;
    final totalPayable  = (loan['total_payable'] as num?)?.toDouble() ?? 0;
    final colStatus     = item['collection_status'] as String? ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
              _StatusBadge(status: colStatus),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _InfoItem(
                label: 'Total Payable',
                value: '₱${NumberFormat('#,##0.00').format(totalPayable)}',
                color: AppColors.primary500,
              ),
              const SizedBox(width: 16),
              _InfoItem(
                label: 'Collected',
                value: '₱${NumberFormat('#,##0.00').format(collectedAmt)}',
                color: AppColors.success,
              ),
            ],
          ),

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary500),
              const SizedBox(width: 4),
              Text(phone,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.primary500)),
            ]),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go(
                '${AppConstants.routeRiderCollect.replaceAll(':collectionId', '')}${item['id']}',
              ),
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Record Collection',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Collection History Card
// ─────────────────────────────────────────────────────────────────────────

class _CollectionHistoryCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  const _CollectionHistoryCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final loan     = (collection['loans'] as Map?)?.cast<String, dynamic>() ?? {};
    final lender   = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user     = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};

    final loanCode     = loan['loan_code'] as String? ?? '-';
    final firstName    = user['first_name'] as String? ?? '';
    final lastName     = user['last_name']  as String? ?? '';
    final borrowerName = '$firstName $lastName'.trim();
    // BUG 3 FIX: collected_amount (not amount)
    final amt       = (collection['collected_amount'] as num?)?.toDouble() ?? 0;
    // BUG 1 FIX: collection_status (not status)
    final status    = collection['collection_status'] as String? ?? '';
    final createdAt = DateTime.tryParse(collection['created_at'] ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'Loan $loanCode • ${createdAt != null ? DateFormat('MMM d, y').format(createdAt) : '-'}',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${NumberFormat('#,##0.00').format(amt)}',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success),
              ),
              _StatusBadge(status: status, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool small;
  const _StatusBadge({required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'pending':    color = AppColors.warning;    break;
      case 'assigned':   color = AppColors.info;       break;
      case 'collecting': color = AppColors.primary500; break;
      case 'completed':  color = AppColors.success;    break;
      case 'failed':     color = AppColors.error;      break;
      default:           color = AppColors.warning;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10,
          vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message, sub;
  const _EmptyView(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text('Failed to load data\n$message',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
          ],
        ),
      ),
    );
  }
}