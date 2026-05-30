// lib/presentation/mobile/pages/dashboard/rider_dashboard_page.dart
// ═══════════════════════════════════════════════════════════════════════════
// FIX SUMMARY (Multiple Runtime Errors):
//
// BUG 1 — Wrong user lookup (runtime PostgREST 0 rows error):
//   ORIGINAL: .eq('id', uid) where uid = Supabase auth UUID
//   The 'users' table's PK 'id' is an app UUID; the Supabase auth UUID is
//   stored in 'auth_id'. So .eq('id', uid) always returns 0 rows.
//   FIX: .eq('auth_id', uid)
//
// BUG 2 — Wrong user name field (null name, avatar shows '?'):
//   ORIGINAL: user['full_name'] — field doesn't exist in schema.
//   Schema has 'first_name' + 'last_name' as separate columns.
//   FIX: '${user['first_name']} ${user['last_name']}'
//
// BUG 3 — Wrong collections table columns (runtime DB error):
//   ORIGINAL columns used: 'amount', 'status', 'collection_date',
//     'loans(borrower_name, loan_number)'
//   ACTUAL schema columns:  'collected_amount', 'collection_status',
//     no 'collection_date' column, loans has 'loan_code' not 'loan_number',
//     and 'borrower_name' doesn't exist (name is on the users table via lenders).
//   FIX: Use correct column names from schema.sql.
//       Use 'created_at' for date filtering (no collection_date column).
//       Join lenders→users for name, or just use lender_id / loan_code.
//
// BUG 4 — Wrong CI table name (runtime: relation does not exist):
//   ORIGINAL: .from('credit_investigations')
//   ACTUAL schema table: 'ci_assignments'
//   FIX: .from('ci_assignments'), with correct column names 'ci_status'
//        and joined loan 'loan_code'.
//
// BUG 5 — Wrong route strings in Quick Actions (GoRouter 404):
//   ORIGINAL used hardcoded strings like '/mobile/collections',
//     '/mobile/ci', '/mobile/loans', '/mobile/profile', '/mobile/notifications'
//   These routes don't exist in app_router.dart.
//   FIX: Use AppConstants route constants.
//
// BUG 6 — riderDashboardProvider uses auth uid as rider_id for collections:
//   'rider_id' in collections table references riders.id (app UUID),
//   NOT the Supabase auth UUID. Must resolve auth_id → users.id → riders.id.
//   FIX: First lookup the rider record by user_id.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
// auth_provider import removed — rider dashboard uses Supabase directly

// ── Provider ──────────────────────────────────────────────────

final riderDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return {};

  final db = Supabase.instance.client;

  // BUG 1 FIX: look up by auth_id, not id
  final user = await db
      .from('users')
      .select('id, first_name, last_name, profile_picture_url')
      .eq('auth_id', authUid)
      .maybeSingle();

  if (user == null) return {'user': {}, 'todayCollections': [], 'todayTotal': 0.0, 'pendingCi': []};

  final userId = user['id'] as String;

  // BUG 6 FIX: resolve users.id → riders.id
  final riderRecord = await db
      .from('riders')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

  if (riderRecord == null) {
    return {
      'user':             user,
      'todayCollections': <dynamic>[],
      'todayTotal':       0.0,
      'pendingCi':        <dynamic>[],
    };
  }

  final riderId = riderRecord['id'] as String;

  // Today's date range for filtering
  final now        = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
  final todayEnd   = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

  // BUG 3 FIX: correct column names — collected_amount, collection_status
  //           no collection_date → use created_at
  //           loans join: loan_code (not loan_number, no borrower_name)
  final allCollections = await db
      .from('collections')
      .select(
        'id, collected_amount, collection_status, created_at, '
        'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name)))',
      )
      .eq('rider_id', riderId)
      .order('created_at', ascending: false)
      .limit(50);

  // BUG 3 FIX: filter today's collections using created_at
  final todayCols = (allCollections as List).where((c) {
    final createdAt = c['created_at'] as String? ?? '';
    return createdAt.compareTo(todayStart) >= 0 &&
        createdAt.compareTo(todayEnd) <= 0;
  }).toList();

  // BUG 3 FIX: sum using collected_amount
  final totalToday = todayCols.fold<double>(
    0,
    (s, c) => s + ((c['collected_amount'] as num?)?.toDouble() ?? 0),
  );

  // BUG 4 FIX: correct table name 'ci_assignments' and column 'ci_status'
  final pendingCi = await db
      .from('ci_assignments')
      .select(
        'id, ci_status, instructions, '
        'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name, '
        'addresses(street, barangay, municipality, province))))',
      )
      .eq('rider_id', riderId)
      .inFilter('ci_status', ['pending', 'ongoing'])
      .order('created_at', ascending: false);

  return {
    'user':             user,
    'todayCollections': todayCols,
    'todayTotal':       totalToday,
    'allCollections':   allCollections,
    'pendingCi':        pendingCi,
  };
});

// ─────────────────────────────────────────────────────────────
// Rider Dashboard Page
// ─────────────────────────────────────────────────────────────

class RiderDashboardPage extends ConsumerWidget {
  const RiderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderDashboardProvider);
    final now       = DateTime.now();
    final greeting  = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final user      = data['user'] as Map<String, dynamic>? ?? {};
          final todayCols = data['todayCollections'] as List<dynamic>? ?? [];
          final todayTotal= data['todayTotal'] as double? ?? 0;
          final pendingCi = data['pendingCi'] as List<dynamic>? ?? [];

          // BUG 2 FIX: schema has first_name + last_name, not full_name
          final firstName = user['first_name'] as String? ?? '';
          final lastName  = user['last_name']  as String? ?? '';
          final name      = '$firstName $lastName'.trim().isEmpty
              ? 'Rider'
              : '$firstName $lastName'.trim();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(riderDashboardProvider),
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  // BUG 2 FIX: use first letter of first_name
                                  child: Text(
                                    firstName.isNotEmpty
                                        ? firstName[0].toUpperCase()
                                        : 'R',
                                    style: const TextStyle(
                                        color:      Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$greeting,',
                                        style: const TextStyle(
                                            color:    Colors.white70,
                                            fontSize: 13)),
                                    Text(name,
                                        style: const TextStyle(
                                            color:      Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize:   17)),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white),
                                  // BUG 5 FIX: use AppConstants route constant
                                  onPressed: () => context.go(
                                      AppConstants.routeRiderNotifications),
                                ),
                              ]),
                              const Spacer(),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(DateTime.now()),
                                style: const TextStyle(
                                    color:    Colors.white70,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Today's Summary ──────────────────
                      Row(children: [
                        Expanded(
                          child: _DashCard(
                            title: "Today's Collections",
                            value: '₱${NumberFormat('#,##0.00').format(todayTotal)}',
                            icon:  Icons.payments_outlined,
                            color: Colors.green,
                            sub:   '${todayCols.length} transactions',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashCard(
                            title: 'Pending CI',
                            value: '${pendingCi.length}',
                            icon:  Icons.assignment_outlined,
                            color: Colors.orange,
                            sub:   'To be visited',
                          ),
                        ),
                      ]).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                      const SizedBox(height: 20),

                      // ── Quick Actions ─────────────────────
                      Text('Quick Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(
                          child: _QuickActionBtn(
                            icon:  Icons.add_circle_outline,
                            label: 'Record\nCollection',
                            color: Colors.blue,
                            // BUG 5 FIX: use AppConstants route constant
                            onTap: () => context.go(
                                AppConstants.routeRiderAssignments),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon:  Icons.search,
                            label: 'CI\nReport',
                            color: Colors.purple,
                            // BUG 5 FIX: assignments route (CI is under assignments)
                            onTap: () => context.go(
                                AppConstants.routeRiderAssignments),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon:  Icons.receipt_long,
                            label: 'My\nProfile',
                            color: Colors.teal,
                            // BUG 5 FIX: use AppConstants route constant
                            onTap: () => context.go(
                                AppConstants.routeRiderProfile),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon:  Icons.person_outline,
                            label: 'Alerts',
                            color: Colors.indigo,
                            // BUG 5 FIX: use AppConstants route constant
                            onTap: () => context.go(
                                AppConstants.routeRiderNotifications),
                          ),
                        ),
                      ]).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                      const SizedBox(height: 20),

                      // ── Pending CI ────────────────────────
                      if (pendingCi.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pending CI Visits',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                            TextButton(
                              // BUG 5 FIX: use AppConstants route constant
                              onPressed: () => context.go(
                                  AppConstants.routeRiderAssignments),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pendingCi
                            .take(3)
                            .map((ci) => _CiTile(ci: ci)),
                        const SizedBox(height: 20),
                      ],

                      // ── Today's Collections ───────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Today's Collections",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold)),
                          TextButton(
                            // BUG 5 FIX: use AppConstants route constant
                            onPressed: () => context.go(
                                AppConstants.routeRiderAssignments),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (todayCols.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size:  40,
                                    color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                    'No collections recorded today',
                                    style: TextStyle(
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...todayCols
                            .take(5)
                            .map((c) => _CollectionTile(collection: c)),

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String   title, value, sub;
  final IconData icon;
  final Color    color;

  const _DashCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                width: 8, height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ]),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
              color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize:   11,
                  color:      color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _CiTile extends StatelessWidget {
  final dynamic ci;
  const _CiTile({required this.ci});

  @override
  Widget build(BuildContext context) {
    // BUG 3/4 FIX: navigate using correct field structure from ci_assignments
    final loan     = ci['loans'] as Map<String, dynamic>? ?? {};
    final lender   = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user     = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final addresses= (user['addresses'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final addr     = addresses.isNotEmpty ? addresses.first : <String,dynamic>{};

    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode     = loan['loan_code'] as String? ?? '-';
    final addressStr   = [
      addr['street'],
      addr['barangay'],
      addr['municipality'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: Colors.orange.withValues(alpha: 0.3))),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child: const Icon(Icons.assignment_outlined,
              color: Colors.orange),
        ),
        title: Text(
          borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '$loanCode${addressStr.isNotEmpty ? ' • $addressStr' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            // BUG 4 FIX: field is 'ci_status', not 'status'
            ((ci['ci_status'] as String?) ?? 'pending').toUpperCase(),
            style: const TextStyle(
                fontSize:   10,
                color:      Colors.orange,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final dynamic collection;
  const _CollectionTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    // BUG 3 FIX: field is 'collected_amount', not 'amount'
    final amt    = (collection['collected_amount'] as num?)?.toDouble() ?? 0;
    final loan   = collection['loans'] as Map<String, dynamic>? ?? {};
    final lender = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user   = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode     = loan['loan_code'] as String? ?? '-';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: const Icon(Icons.payments_outlined,
              color: Colors.green),
        ),
        title: Text(
          borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('Loan $loanCode',
            style: const TextStyle(fontSize: 12)),
        trailing: Text(
          '₱${NumberFormat('#,##0.00').format(amt)}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
}