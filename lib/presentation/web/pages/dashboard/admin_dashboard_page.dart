// lib/presentation/web/pages/dashboard/admin_dashboard_page.dart
// Jireta Loans & Credit Corp. 1996 — Admin Dashboard
//
// ═══════════════════════════════════════════════════════════════════════════
// BUG FIX — ROOT CAUSE of mouse_tracker.dart:199 assertion cascade +
//           "Cannot hit test a render box that has never been laid out"
//
// ORIGINAL BUG (_RecentActivityPanel was a ConsumerWidget):
//   Widget build(BuildContext context, WidgetRef ref) {
//     // ← NEW stream created on EVERY build() call
//     final stream = Supabase.instance.client
//         .from('audit_logs')
//         .stream(primaryKey: ['id'])
//         ...;
//     return StreamBuilder(stream: stream, ...);  // ← detects stream changed
//   }
//
// WHY THIS BREAKS EVERYTHING:
//   1. build() runs → new Stream object created
//   2. StreamBuilder sees the stream reference changed → switches to new stream
//   3. Supabase stream immediately emits cached data
//   4. StreamBuilder setState → triggers parent rebuild
//   5. parent build() runs → another new Stream created → goto 1
//   This tight loop fires hundreds of times per second.
//   During the loop, MouseRegion widgets are repeatedly added/removed,
//   causing mouse_tracker.dart assertion failures (line 199).
//   Also, widgets are rebuilt before layout completes →
//   "Cannot hit test a render box that has never been laid out".
//   The entire web UI becomes unclickable.
//
// FIX:
//   Convert _RecentActivityPanel to ConsumerStatefulWidget.
//   Create the stream ONCE in initState() and store it in _stream.
//   StreamBuilder always receives the same stream object → no loop.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

// ── Providers ────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sb = Supabase.instance.client;
  final results = await Future.wait([
    sb.from('loans').select('loan_status').eq('is_archived', false),
    sb.from('payments').select('amount').eq('payment_status', 'completed'),
    sb.from('users').select('id').eq('is_archived', false),
    sb.from('collections').select('collection_status').eq('is_archived', false),
  ]);

  final loans       = results[0] as List;
  final payments    = results[1] as List;
  final users       = results[2] as List;
  final collections = results[3] as List;

  final pending   = loans.where((l) => l['loan_status'] == 'pending').length;
  final active    = loans.where((l) => l['loan_status'] == 'active').length;
  final overdue   = loans.where((l) => l['loan_status'] == 'overdue').length;
  final completed = loans.where((l) => l['loan_status'] == 'completed').length;
  final underCI   = loans.where((l) => l['loan_status'] == 'under_ci').length;

  final totalRevenue = payments.fold<double>(
      0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

  return {
    'pending_loans':   pending,
    'active_loans':    active,
    'overdue_loans':   overdue,
    'completed_loans': completed,
    'under_ci_loans':  underCI,
    'total_loans':     loans.length,
    'total_revenue':   totalRevenue,
    'total_users':     users.length,
    'pending_collections':
        collections.where((c) => c['collection_status'] == 'pending').length,
  };
});

// ─────────────────────────────────────────────────────────────
// Admin Dashboard
// ─────────────────────────────────────────────────────────────

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats     = ref.watch(dashboardStatsProvider);
    final user      = ref.watch(authStateProvider).value;
    final firstName = user?['first_name'] as String? ?? 'Admin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardStatsProvider.future),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_greeting()}, $firstName 👋',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s your lending overview for today',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Realtime indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeOut(duration: 800.ms, curve: Curves.easeInOut)
                            .then()
                            .fadeIn(duration: 800.ms),
                        const SizedBox(width: 6),
                        const Text(
                          'Realtime',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 28),

              // ── Stats Cards ────────────────────────────────
              stats.when(
                loading: () => _StatsGridSkeleton(),
                error: (_, __) => const _ErrorWidget(),
                data: (data) => _StatsGrid(data: data),
              ),

              const SizedBox(height: 28),

              // ── Charts Row ─────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _LoanStatusChart()),
                            const SizedBox(width: 20),
                            // ✅ FIX: _RecentActivityPanel is now a
                            //         StatefulWidget so the stream is
                            //         created ONCE in initState, not on
                            //         every build().
                            const Expanded(flex: 2, child: _RecentActivityPanel()),
                          ],
                        )
                      : Column(
                          children: [
                            _LoanStatusChart(),
                            const SizedBox(height: 20),
                            const _RecentActivityPanel(),
                          ],
                        );
                },
              ).animate(delay: 300.ms).fadeIn(duration: 500.ms),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ─────────────────────────────────────────────────────────────
// Stats Grid
// ─────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatDef(
        title: 'Total Loans',
        value: '${data['total_loans'] ?? 0}',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.primary500,
        bg: AppColors.primary50,
        trend: '+12%',
      ),
      _StatDef(
        title: 'Active Loans',
        value: '${data['active_loans'] ?? 0}',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
        bg: AppColors.successLight,
        trend: '+8%',
      ),
      _StatDef(
        title: 'Pending Review',
        value: '${data['pending_loans'] ?? 0}',
        icon: Icons.pending_actions_rounded,
        color: AppColors.warning,
        bg: AppColors.warningLight,
        trend: '${data['under_ci_loans'] ?? 0} under CI',
      ),
      _StatDef(
        title: 'Overdue Loans',
        value: '${data['overdue_loans'] ?? 0}',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        bg: AppColors.errorLight,
        trend: 'Needs attention',
      ),
      _StatDef(
        title: 'Total Revenue',
        value: '₱${_fmt(data['total_revenue'] as double? ?? 0)}',
        icon: Icons.monetization_on_rounded,
        color: AppColors.accent,
        bg: AppColors.accentLight,
        trend: 'Completed loans',
      ),
      _StatDef(
        title: 'Total Users',
        value: '${data['total_users'] ?? 0}',
        icon: Icons.people_rounded,
        color: AppColors.info,
        bg: AppColors.infoLight,
        trend: 'All roles',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _StatCard(def: cards[i])
          .animate(delay: (100 * i).ms)
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.2, curve: Curves.easeOutCubic),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatDef {
  final String title, value, trend;
  final IconData icon;
  final Color color, bg;

  const _StatDef({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    required this.trend,
  });
}

class _StatCard extends StatefulWidget {
  final _StatDef def;
  const _StatCard({required this.def});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.def.color.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.def.color.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? widget.def.color.withValues(alpha: 0.15)
                        : widget.def.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.def.icon,
                      color: widget.def.color, size: 22),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? widget.def.color.withValues(alpha: 0.15)
                        : widget.def.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.def.trend,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.def.color,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.def.value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  widget.def.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loan Status Pie Chart
// ─────────────────────────────────────────────────────────────

class _LoanStatusChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = [
      PieChartSectionData(
          value: 35,
          color: AppColors.primary500,
          title: 'Active\n35%',
          radius: 80,
          titleStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
      PieChartSectionData(
          value: 25,
          color: AppColors.warning,
          title: 'Pending\n25%',
          radius: 80,
          titleStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
      PieChartSectionData(
          value: 20,
          color: AppColors.success,
          title: 'Done\n20%',
          radius: 80,
          titleStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
      PieChartSectionData(
          value: 12,
          color: AppColors.error,
          title: 'Overdue\n12%',
          radius: 80,
          titleStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
      PieChartSectionData(
          value: 8,
          color: AppColors.accent,
          title: 'CI\n8%',
          radius: 80,
          titleStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Loan Status Distribution',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Recent Activity Panel
// ─────────────────────────────────────────────────────────────
//
// ✅ KEY FIX: Changed from ConsumerWidget → ConsumerStatefulWidget.
//    Stream is created ONCE in initState() and stored in _stream.
//    StreamBuilder always receives the same Stream object, so it does NOT
//    re-subscribe on every build() call.  The infinite rebuild loop is gone.
// ─────────────────────────────────────────────────────────────

class _RecentActivityPanel extends ConsumerStatefulWidget {
  const _RecentActivityPanel();

  @override
  ConsumerState<_RecentActivityPanel> createState() =>
      _RecentActivityPanelState();
}

class _RecentActivityPanelState extends ConsumerState<_RecentActivityPanel> {
  // ✅ FIX: Stream stored in state, created ONCE.
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Create stream here, not in build().
    _stream = Supabase.instance.client
        .from('audit_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(8);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Live',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            // ✅ FIX: Uses _stream (same object every build) — no more loop.
            stream: _stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No recent activity',
                        style: TextStyle(fontFamily: 'Poppins')),
                  ),
                );
              }
              return Column(
                children: logs.map((log) {
                  final action = log['action'] as String? ?? '';
                  final description = log['description'] as String? ?? '';
                  final table = log['table_name'] as String? ?? '';
                  final createdAt =
                      DateTime.tryParse(log['created_at'] ?? '');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _actionColor(action)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_actionIcon(action),
                              color: _actionColor(action), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(description,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${table.replaceAll('_', ' ')} • ${_timeAgo(createdAt)}',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':  return AppColors.success;
      case 'update':  return AppColors.info;
      case 'archive': return AppColors.warning;
      case 'approve': return AppColors.success;
      case 'reject':  return AppColors.error;
      case 'login':   return AppColors.primary500;
      case 'payment': return AppColors.accent;
      default:        return AppColors.primary400;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':  return Icons.add_circle_outline_rounded;
      case 'update':  return Icons.edit_rounded;
      case 'archive': return Icons.archive_rounded;
      case 'approve': return Icons.check_circle_outline_rounded;
      case 'reject':  return Icons.cancel_outlined;
      case 'login':   return Icons.login_rounded;
      case 'payment': return Icons.payment_rounded;
      default:        return Icons.info_outline_rounded;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────
// Skeleton + Error
// ─────────────────────────────────────────────────────────────

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
              duration: 1200.ms,
              color: AppColors.primary100.withValues(alpha: 0.4)),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 40),
            SizedBox(height: 8),
            Text('Failed to load dashboard data',
                style: TextStyle(fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}