// lib/presentation/mobile/pages/dashboard/rider_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

final riderDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return {};

  final db = Supabase.instance.client;

  final user = await db
      .from('users')
      .select()
      .eq('id', uid)
      .maybeSingle();

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final collections = await db
      .from('collections')
      .select('amount, status, collection_date, loans(borrower_name, loan_number)')
      .eq('rider_id', uid)
      .order('collection_date', ascending: false)
      .limit(50);

  final todayCols = (collections as List)
      .where((c) => (c['collection_date'] ?? '').toString().startsWith(today))
      .toList();

  final totalToday = todayCols.fold<double>(
      0, (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0));

  final pendingCi = await db
      .from('credit_investigations')
      .select('*, loans(borrower_name, loan_number, amount, address)')
      .eq('rider_id', uid)
      .inFilter('status', ['pending', 'ongoing'])
      .order('created_at', ascending: false);

  return {
    'user': user ?? {},
    'todayCollections': todayCols,
    'todayTotal': totalToday,
    'allCollections': collections,
    'pendingCi': pendingCi,
  };
});

class RiderDashboardPage extends ConsumerWidget {
  const RiderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderDashboardProvider);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final user = data['user'] as Map<String, dynamic>? ?? {};
          final todayCols =
              data['todayCollections'] as List<dynamic>? ?? [];
          final todayTotal = data['todayTotal'] as double? ?? 0;
          final pendingCi = data['pendingCi'] as List<dynamic>? ?? [];
          final name = user['full_name'] as String? ?? 'Rider';

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(riderDashboardProvider),
            child: CustomScrollView(
              slivers: [
                // ── App Bar ────────────────────────────────────────────────
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
                          end: Alignment.bottomRight,
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
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('$greeting,',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13)),
                                      Text(name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17)),
                                    ]),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.notifications_outlined,
                                      color: Colors.white),
                                  onPressed: () =>
                                      context.go('/mobile/notifications'),
                                ),
                              ]),
                              const Spacer(),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(DateTime.now()),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
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
                      // ── Today's Summary ──────────────────────────────────
                      Row(children: [
                        Expanded(
                          child: _DashCard(
                            title: "Today's Collections",
                            value: '₱${NumberFormat('#,##0.00').format(todayTotal)}',
                            icon: Icons.payments_outlined,
                            color: Colors.green,
                            sub: '${todayCols.length} transactions',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashCard(
                            title: 'Pending CI',
                            value: '${pendingCi.length}',
                            icon: Icons.assignment_outlined,
                            color: Colors.orange,
                            sub: 'To be visited',
                          ),
                        ),
                      ]).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                      const SizedBox(height: 20),

                      // ── Quick Actions ────────────────────────────────────
                      Text("Quick Actions",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(
                          child: _QuickActionBtn(
                            icon: Icons.add_circle_outline,
                            label: 'Record\nCollection',
                            color: Colors.blue,
                            onTap: () =>
                                context.go('/mobile/collections'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon: Icons.search,
                            label: 'CI\nReport',
                            color: Colors.purple,
                            onTap: () => context.go('/mobile/ci'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon: Icons.receipt_long,
                            label: 'My\nLoans',
                            color: Colors.teal,
                            onTap: () => context.go('/mobile/loans'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionBtn(
                            icon: Icons.person_outline,
                            label: 'My\nProfile',
                            color: Colors.indigo,
                            onTap: () =>
                                context.go('/mobile/profile'),
                          ),
                        ),
                      ]).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                      const SizedBox(height: 20),

                      // ── Pending CI ────────────────────────────────────────
                      if (pendingCi.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pending CI Visits',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () =>
                                  context.go('/mobile/ci'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pendingCi.take(3).map((ci) => _CiTile(ci: ci)),
                        const SizedBox(height: 20),
                      ],

                      // ── Today's Collections ────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Today's Collections",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () =>
                                context.go('/mobile/collections'),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('No collections recorded today',
                                      style:
                                          TextStyle(color: Colors.grey)),
                                ]),
                          ),
                        )
                      else
                        ...todayCols.take(5).map(
                            (c) => _CollectionTile(collection: c)),

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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String title, value, sub;
  final IconData icon;
  final Color color;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Container(
              width: 8,
              height: 8,
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
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3))),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child:
              const Icon(Icons.assignment_outlined, color: Colors.orange),
        ),
        title: Text(
          ci['loans']?['borrower_name'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Loan #${ci['loans']?['loan_number'] ?? '-'} • ${ci['loans']?['address'] ?? 'No address'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            (ci['status'] as String? ?? 'pending').toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                color: Colors.orange,
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
    final amt = (collection['amount'] as num?)?.toDouble() ?? 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: const Icon(Icons.payments_outlined, color: Colors.green),
        ),
        title: Text(
          collection['loans']?['borrower_name'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
            'Loan #${collection['loans']?['loan_number'] ?? '-'}',
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