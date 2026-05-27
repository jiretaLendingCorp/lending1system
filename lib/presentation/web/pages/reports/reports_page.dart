// lib/presentation/web/pages/reports/reports_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final reportSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final db = Supabase.instance.client;

  final loans = await db.from('loans').select('amount, status, created_at');
  final collections =
      await db.from('collections').select('amount, collection_date');

  double totalDisbursed = 0;
  double totalCollected = 0;
  int activeLoans = 0;
  int overdueLoans = 0;
  final monthly = <String, double>{};

  for (final l in loans as List) {
    final amt = (l['amount'] as num?)?.toDouble() ?? 0;
    totalDisbursed += amt;
    if (l['status'] == 'active') activeLoans++;
    if (l['status'] == 'overdue') overdueLoans++;

    final d = l['created_at'];
    if (d != null) {
      final dt = DateTime.tryParse(d.toString());
      if (dt != null) {
        final key = DateFormat('MMM yy').format(dt);
        monthly[key] = (monthly[key] ?? 0) + amt;
      }
    }
  }

  for (final c in collections as List) {
    totalCollected += (c['amount'] as num?)?.toDouble() ?? 0;
  }

  return {
    'totalDisbursed': totalDisbursed,
    'totalCollected': totalCollected,
    'activeLoans': activeLoans,
    'overdueLoans': overdueLoans,
    'monthly': monthly,
  };
});

final reportRangeProvider =
    StateProvider<String>((ref) => 'last6months');

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports & Analytics',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Financial overview and performance metrics',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export PDF'),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () {},
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            summaryAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI Cards ────────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Total Disbursed',
                        value:
                            '₱${NumberFormat('#,##0.00').format(s['totalDisbursed'])}',
                        icon: Icons.arrow_upward,
                        color: Colors.blue,
                        sub: 'All-time loan releases',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _KpiCard(
                        label: 'Total Collected',
                        value:
                            '₱${NumberFormat('#,##0.00').format(s['totalCollected'])}',
                        icon: Icons.arrow_downward,
                        color: Colors.green,
                        sub: 'All-time collections',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _KpiCard(
                        label: 'Active Loans',
                        value: '${s['activeLoans']}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                        sub: 'Currently running',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _KpiCard(
                        label: 'Overdue Loans',
                        value: '${s['overdueLoans']}',
                        icon: Icons.warning_amber,
                        color: Colors.red,
                        sub: 'Needs attention',
                      ),
                    ),
                  ]).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                  const SizedBox(height: 24),

                  // ── Collection Rate ────────────────────────────────────
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collection Rate',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              'Collected vs Disbursed',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 20),
                          Builder(builder: (ctx) {
                            final pct = s['totalDisbursed'] > 0
                                ? (s['totalCollected'] /
                                        s['totalDisbursed'] *
                                        100)
                                    .clamp(0, 100)
                                    .toDouble()
                                : 0.0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '${pct.toStringAsFixed(1)}% collected',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '₱${NumberFormat('#,##0').format(s['totalDisbursed'] - s['totalCollected'])} outstanding'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    minHeight: 12,
                                    backgroundColor:
                                        Colors.grey.shade200,
                                    color: pct >= 80
                                        ? Colors.green
                                        : pct >= 50
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                  const SizedBox(height: 24),

                  // ── Monthly Disbursements Chart ───────────────────────
                  if ((s['monthly'] as Map).isNotEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Loan Disbursements',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 220,
                              child: _MonthlyBarChart(
                                  data: Map<String, double>.from(
                                      s['monthly'])),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Monthly Bar Chart ─────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, double> data;
  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '₱${NumberFormat('#,##0').format(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (v, _) => Text(
                '₱${NumberFormat.compact().format(v)}',
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= 0 && i < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(entries[i].key,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          entries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Icon(Icons.trending_up, color: Colors.green.shade400, size: 16),
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
    );
  }
}