// lib/presentation/mobile/pages/history/rider_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

final _riderAppUserIdProvider = FutureProvider<String?>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final user = await Supabase.instance.client
      .from('users')
      .select('id')
      .eq('auth_id', uid)
      .maybeSingle();
  return user?['id'] as String?;
});

final _riderRecordIdProvider = FutureProvider<String?>((ref) async {
  final userId = await ref.watch(_riderAppUserIdProvider.future);
  if (userId == null) return null;
  final rider = await Supabase.instance.client
      .from('riders')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  return rider?['id'] as String?;
});

final _riderCompletedCiProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await ref.watch(_riderRecordIdProvider.future);
  if (riderId == null) return [];

  return await Supabase.instance.client
      .from('ci_assignments')
      .select(
        'id, ci_status, completed_at, created_at, '
        'loans(loan_code, '
        'lenders(users(first_name, last_name), '
        'addresses(street, barangay, municipality)))',
      )
      .eq('rider_id', riderId)
      .eq('ci_status', 'completed')
      .order('completed_at', ascending: false)
      .limit(100);
});

final _riderCompletedCollectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final riderId = await ref.watch(_riderRecordIdProvider.future);
  if (riderId == null) return [];

  return await Supabase.instance.client
      .from('collections')
      .select(
        'id, collection_code, collected_amount, collection_status, created_at, '
        'loans(loan_code, '
        'lenders(users(first_name, last_name)))',
      )
      .eq('rider_id', riderId)
      .eq('collection_status', 'collected')
      .order('created_at', ascending: false)
      .limit(100);
});

class RiderHistoryPage extends ConsumerStatefulWidget {
  const RiderHistoryPage({super.key});

  @override
  ConsumerState<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends ConsumerState<RiderHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'My History',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(_riderCompletedCiProvider);
              ref.invalidate(_riderCompletedCollectionsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          tabs: const [
            Tab(text: 'CI Visits'),
            Tab(text: 'Collections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CiHistoryTab(isDark: isDark),
          _CollectionsHistoryTab(isDark: isDark),
        ],
      ),
    );
  }
}

class _CiHistoryTab extends ConsumerWidget {
  final bool isDark;
  const _CiHistoryTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciAsync = ref.watch(_riderCompletedCiProvider);

    return ciAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_riderCompletedCiProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyView(
              label: 'No completed CI visits',
              sub: 'Completed credit investigations appear here');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_riderCompletedCiProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final ci = list[i];
              final loan = ci['loans'] as Map<String, dynamic>? ?? {};
              final lender =
                  loan['lenders'] as Map<String, dynamic>? ?? {};
              final lenderUser =
                  lender['users'] as Map<String, dynamic>? ?? {};
              final address =
                  lender['addresses'] as Map<String, dynamic>?;
              final name =
                  '${lenderUser['first_name'] ?? ''} ${lenderUser['last_name'] ?? ''}'
                      .trim();
              final loanCode = loan['loan_code'] as String? ?? '—';
              final rawDate =
                  ci['completed_at'] ?? ci['created_at'];
              final date = rawDate != null
                  ? DateFormat('MMM d, yyyy').format(
                      DateTime.parse(rawDate as String).toLocal())
                  : '—';
              final location = address != null
                  ? '${address['barangay'] ?? ''}, ${address['municipality'] ?? ''}'
                      .trim()
                      .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                  : '—';

              return _CiCard(
                name: name.isEmpty ? 'Unknown' : name,
                loanCode: loanCode,
                date: date,
                location: location,
                isDark: isDark,
              )
                  .animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          ),
        );
      },
    );
  }
}

class _CollectionsHistoryTab extends ConsumerWidget {
  final bool isDark;
  const _CollectionsHistoryTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colAsync = ref.watch(_riderCompletedCollectionsProvider);

    return colAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_riderCompletedCollectionsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyView(
              label: 'No completed collections',
              sub: 'Payments you collected will appear here');
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_riderCompletedCollectionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final col  = list[i];
              final loan =
                  col['loans'] as Map<String, dynamic>? ?? {};
              final lender =
                  loan['lenders'] as Map<String, dynamic>? ?? {};
              final lenderUser =
                  lender['users'] as Map<String, dynamic>? ?? {};
              final name =
                  '${lenderUser['first_name'] ?? ''} ${lenderUser['last_name'] ?? ''}'
                      .trim();
              final amount =
                  (col['collected_amount'] as num?)?.toDouble() ?? 0;
              final loanCode = loan['loan_code'] as String? ?? '—';
              final code = col['collection_code'] as String? ?? '—';
              final date = col['created_at'] != null
                  ? DateFormat('MMM d, yyyy').format(
                      DateTime.parse(col['created_at'] as String).toLocal())
                  : '—';

              return _CollectionCard(
                name: name.isEmpty ? 'Unknown' : name,
                loanCode: loanCode,
                collectionCode: code,
                amount: amount,
                date: date,
                isDark: isDark,
              )
                  .animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          ),
        );
      },
    );
  }
}

class _CiCard extends StatelessWidget {
  final String name, loanCode, date, location;
  final bool   isDark;

  const _CiCard({
    required this.name,
    required this.loanCode,
    required this.date,
    required this.location,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loanCode,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (location.isNotEmpty && location != '—') ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_rounded,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final String name, loanCode, collectionCode, date;
  final double amount;
  final bool   isDark;

  const _CollectionCard({
    required this.name,
    required this.loanCode,
    required this.collectionCode,
    required this.amount,
    required this.date,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded,
                color: AppColors.primary500, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loanCode,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                collectionCode,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₱${fmt.format(amount)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String label, sub;
  const _EmptyView({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ]),
      ),
    );
  }
}