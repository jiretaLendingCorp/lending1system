// lib/presentation/web/pages/dashboard/employee_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/auth_provider.dart';

final employeeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sb = Supabase.instance.client;
  final results = await Future.wait([
    sb.from('loans').select('loan_status').eq('is_archived', false),
    sb.from('collections').select('collection_status').eq('is_archived', false),
    sb.from('ci_assignments').select('ci_status'),
    sb.from('lenders').select('id'),
  ]);

  final loans = results[0] as List;
  final cols = results[1] as List;
  final ci = results[2] as List;
  final lenders = results[3] as List;

  return {
    'pending_loans': loans.where((l) => l['loan_status'] == 'pending').length,
    'active_loans': loans.where((l) => l['loan_status'] == 'active').length,
    'overdue_loans': loans.where((l) => l['loan_status'] == 'overdue').length,
    'under_ci': loans.where((l) => l['loan_status'] == 'under_ci').length,
    'total_loans': loans.length,
    'pending_cols':
        cols.where((c) => c['collection_status'] == 'pending').length,
    'done_cols':
        cols.where((c) => c['collection_status'] == 'completed').length,
    'pending_ci': ci.where((c) => c['ci_status'] == 'pending').length,
    'total_lenders': lenders.length,
  };
});

final _empRecentLoansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await Supabase.instance.client
      .from('loans')
      .select(
        'id, loan_code, loan_status, principal_amount, created_at, '
        'lenders!inner(users!inner(first_name, last_name))',
      )
      .eq('is_archived', false)
      .inFilter('loan_status', ['pending', 'under_ci'])
      .order('created_at', ascending: false)
      .limit(8);
});

class EmployeeDashboardPage extends ConsumerWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(employeeStatsProvider);
    final loans = ref.watch(_empRecentLoansProvider);
    final user = ref.watch(authStateProvider).value;
    final firstName = user?['first_name'] as String? ?? 'Employee';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeeStatsProvider);
          ref.invalidate(_empRecentLoansProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, $firstName!',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      Text('Operations Overview',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded,
                            size: 14, color: AppColors.primary600),
                        SizedBox(width: 6),
                        Text('Employee',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary600)),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),
              stats.when(
                loading: () => _SkeletonGrid(),
                error: (e, _) => Text('Error loading stats: $e'),
                data: (s) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _StatCard(
                                label: 'Pending Loans',
                                value: '${s['pending_loans']}',
                                icon: Icons.pending_actions_rounded,
                                color: AppColors.warning,
                                onTap: () =>
                                    context.go(AppConstants.routeWebLoans))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Active Loans',
                                value: '${s['active_loans']}',
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                                onTap: () =>
                                    context.go(AppConstants.routeWebLoans))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Overdue Loans',
                                value: '${s['overdue_loans']}',
                                icon: Icons.warning_rounded,
                                color: AppColors.error,
                                onTap: () =>
                                    context.go(AppConstants.routeWebLoans))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Under CI',
                                value: '${s['under_ci']}',
                                icon: Icons.search_rounded,
                                color: AppColors.statusUnderCI,
                                onTap: () =>
                                    context.go(AppConstants.routeWebCI))),
                      ],
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _StatCard(
                                label: 'Pending Collections',
                                value: '${s['pending_cols']}',
                                icon: Icons.payments_outlined,
                                color: AppColors.primary500,
                                onTap: () => context
                                    .go(AppConstants.routeWebCollections))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Done Collections',
                                value: '${s['done_cols']}',
                                icon: Icons.done_all_rounded,
                                color: AppColors.success,
                                onTap: () => context
                                    .go(AppConstants.routeWebCollections))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Pending CI',
                                value: '${s['pending_ci']}',
                                icon: Icons.assignment_outlined,
                                color: AppColors.warning,
                                onTap: () =>
                                    context.go(AppConstants.routeWebCI))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _StatCard(
                                label: 'Total Lenders',
                                value: '${s['total_lenders']}',
                                icon: Icons.people_alt_outlined,
                                color: AppColors.accent,
                                onTap: () =>
                                    context.go(AppConstants.routeWebLenders))),
                      ],
                    ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _PendingLoansPanel(
                      loans: loans,
                      onViewAll: () => context.go(AppConstants.routeWebLoans),
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: _QuickLinksPanel()
                        .animate(delay: 250.ms)
                        .fadeIn(duration: 400.ms),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (!mounted || _hovered == hovered) return;
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  Icon(Icons.trending_up_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.value,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: widget.color,
                      height: 1)),
              const SizedBox(height: 4),
              Text(widget.label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingLoansPanel extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> loans;
  final VoidCallback onViewAll;
  const _PendingLoansPanel({required this.loans, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Loans Requiring Action',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12))),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          loans.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $e',
                    style: const TextStyle(fontFamily: 'Poppins'))),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('No pending loans',
                            style: TextStyle(fontFamily: 'Poppins'))))
                : Column(
                    children: list.asMap().entries.map((e) {
                      final loan = e.value;
                      final status = loan['loan_status'] as String? ?? '';
                      final sc = AppColors.loanStatusColor(status);
                      final lender =
                          (loan['lenders'] as Map?)?.cast<String, dynamic>() ??
                              {};
                      final u =
                          (lender['users'] as Map?)?.cast<String, dynamic>() ??
                              {};
                      final name =
                          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                              .trim();
                      final code = loan['loan_code'] as String? ?? '';
                      final amt =
                          (loan['principal_amount'] as num?)?.toDouble() ?? 0;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: sc.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: sc,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? 'Unknown' : name,
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(code,
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Text('₱${_fmt(amt)}',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: sc.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(_statusLabel(status),
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: sc)),
                                ),
                              ],
                            ),
                          ),
                          if (e.key < list.length - 1)
                            Divider(
                                height: 1,
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _statusLabel(String s) {
    const map = {
      'pending': 'Pending',
      'under_ci': 'Under CI',
      'approved': 'Approved',
      'active': 'Active',
      'overdue': 'Overdue'
    };
    return map[s] ?? s;
  }
}

class _QuickLinksPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final links = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'label': 'Loans',
        'sub': 'Manage applications',
        'route': AppConstants.routeWebLoans,
        'color': AppColors.primary500
      },
      {
        'icon': Icons.payments_rounded,
        'label': 'Collections',
        'sub': 'Track payments',
        'route': AppConstants.routeWebCollections,
        'color': AppColors.success
      },
      {
        'icon': Icons.search_rounded,
        'label': 'Credit Invest.',
        'sub': 'CI assignments',
        'route': AppConstants.routeWebCI,
        'color': AppColors.statusUnderCI
      },
      {
        'icon': Icons.person_search_rounded,
        'label': 'Lenders',
        'sub': 'View borrowers',
        'route': AppConstants.routeWebLenders,
        'color': AppColors.accent
      },
      {
        'icon': Icons.delivery_dining_rounded,
        'label': 'Riders',
        'sub': 'Field agents',
        'route': AppConstants.routeWebRiders,
        'color': AppColors.warning
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Navigation',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...links.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuickLink(
                  icon: l['icon'] as IconData,
                  label: l['label'] as String,
                  sub: l['sub'] as String,
                  color: l['color'] as Color,
                  route: l['route'] as String,
                ),
              )),
        ],
      ),
    );
  }
}

class _QuickLink extends StatefulWidget {
  final IconData icon;
  final String label, sub, route;
  final Color color;
  const _QuickLink(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.route});
  @override
  State<_QuickLink> createState() => _QuickLinkState();
}

class _QuickLinkState extends State<_QuickLink> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (!mounted || _hovered == hovered) return;
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go(widget.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.3)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(widget.sub,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: _hovered
                      ? widget.color
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(
              4,
              (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 3 ? 16 : 0),
                      height: 100,
                      decoration: BoxDecoration(
                          color: AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(16)),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(
                        duration: 1200.ms,
                        color: AppColors.primary100.withValues(alpha: 0.3)),
                  )),
        ),
      ],
    );
  }
}
