// lib/presentation/mobile/pages/dashboard/lender_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/auth_provider.dart';

final lenderActiveLoansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final lender = await Supabase.instance.client
      .from('lenders')
      .select('id, lender_code, credit_score, risk_level')
      .eq('user_id', userId)
      .maybeSingle();

  if (lender == null) return [];

  return await Supabase.instance.client
      .from('loans')
      .select('*, loan_schedules(due_date, due_amount, is_paid, is_overdue)')
      .eq('lender_id', lender['id'])
      .eq('is_archived', false)
      .order('created_at', ascending: false)
      .limit(5);
});

final lenderProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final lender = await Supabase.instance.client
      .from('lenders')
      .select('id, lender_code, credit_score, risk_level, monthly_income, occupation')
      .eq('user_id', userId)
      .maybeSingle();

  return lender ?? {};
});

final lenderNotifCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);

  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', userId)
      .map((rows) => rows.where((r) => r['is_read'] == false).length);
});

class LenderDashboardPage extends ConsumerWidget {
  const LenderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final user        = ref.watch(authStateProvider).value;
    final loans       = ref.watch(lenderActiveLoansProvider);
    final lenderInfo  = ref.watch(lenderProfileProvider);
    final notifCount  = ref.watch(lenderNotifCountProvider).value ?? 0;
    final firstName   = user?['first_name'] as String? ?? 'there';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lenderActiveLoansProvider);
          ref.invalidate(lenderProfileProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned:  true,
              stretch: true,
              backgroundColor: AppColors.primary600,
              elevation:       0,
              actions: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => context.go(AppConstants.routeLenderNotifications),
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                    ),
                    if (notifCount > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          child: Text(
                            notifCount > 9 ? '9+' : '$notifCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _LenderHeroHeader(
                  firstName:   firstName,
                  loans:       loans.value ?? [],
                  lenderInfo:  lenderInfo.value ?? {},
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CapabilityCards(lenderInfo: lenderInfo.value ?? {}),

                  const SizedBox(height: 20),

                  _QuickActions(),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Loans', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => context.go(AppConstants.routeLenderLoans),
                        child: const Text('See all', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  loans.when(
                    loading: () => _LoanCardSkeleton(),
                    error:   (_, __) => const _ErrorWidget(),
                    data: (loanList) => loanList.isEmpty
                        ? _EmptyLoansWidget()
                        : Column(
                            children: loanList.asMap().entries.map((e) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _LoanCard(loan: e.value),
                              ).animate(delay: (80 * e.key).ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),
                            ).toList(),
                          ),
                  ),

                  const SizedBox(height: 24),

                  _ApplyLoanBanner(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LenderHeroHeader extends StatelessWidget {
  final String firstName;
  final List<Map<String, dynamic>> loans;
  final Map<String, dynamic> lenderInfo;

  const _LenderHeroHeader({
    required this.firstName,
    required this.loans,
    required this.lenderInfo,
  });

  @override
  Widget build(BuildContext context) {
    final totalBalance = loans
        .where((l) => ['active', 'overdue'].contains(l['loan_status']))
        .fold<double>(0, (s, l) => s + ((l['outstanding_balance'] as num?)?.toDouble() ?? 0));

    final lenderCode = lenderInfo['lender_code'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/lender_hero.png',
                width:  200,
                height: 200,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 200, height: 200,
                  child: Icon(Icons.account_balance, size: 160, color: Colors.white),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, $firstName 👋',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, color: Colors.white70)),
                            const Text('Your Loan Overview',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                      ),
                      if (lenderCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(lenderCode, style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Outstanding Balance',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(
                              '₱${_fmt(totalBalance)}',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _CapabilityCards extends StatelessWidget {
  final Map<String, dynamic> lenderInfo;
  const _CapabilityCards({required this.lenderInfo});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final creditScore = lenderInfo['credit_score'] as num? ?? 0;
    final riskLevel   = lenderInfo['risk_level'] as String? ?? 'medium';

    final riskColor = riskLevel == 'low' ? AppColors.success
        : riskLevel == 'high' ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Overview', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoTile(label: 'Credit Score', value: '$creditScore', color: AppColors.primary500),
              const SizedBox(width: 10),
              _InfoTile(label: 'Risk Level',   value: riskLevel.toUpperCase(), color: riskColor),
              const SizedBox(width: 10),
              const _InfoTile(label: 'Loan Limit',   value: '₱500K', color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary600),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can apply for loans, make payments, and upload documents.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.primary700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(label,  style: TextStyle(fontFamily: 'Poppins', fontSize: 9,  color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      const _ActionDef('Apply Loan',  Icons.add_card_rounded,        AppColors.primary500, AppConstants.routeLenderApply),
      const _ActionDef('Pay Now',     Icons.payment_rounded,         AppColors.success,    AppConstants.routeLenderLoans),
      const _ActionDef('Documents',   Icons.description_rounded,     AppColors.warning,    AppConstants.routeLenderDocuments),
      const _ActionDef('Profile',     Icons.manage_accounts_rounded, AppColors.accent,     AppConstants.routeLenderProfile),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: actions.asMap().entries.map((e) {
            final a = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < actions.length - 1 ? 10 : 0),
                child: _ActionButton(def: a),
              ).animate(delay: (60 * e.key).ms).fadeIn(duration: 350.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ActionDef {
  final String label, route;
  final IconData icon;
  final Color color;
  const _ActionDef(this.label, this.icon, this.color, this.route);
}

class _ActionButton extends StatefulWidget {
  final _ActionDef def;
  const _ActionButton({required this.def});
  @override State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  @override void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); context.go(widget.def.route); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [BoxShadow(color: widget.def.color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        widget.def.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.def.icon, color: widget.def.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(widget.def.label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final status      = loan['loan_status'] as String? ?? '';
    final statusColor = AppColors.loanStatusColor(status);
    final code        = loan['loan_code'] as String? ?? '';
    final principal   = (loan['principal_amount'] as num?)?.toDouble() ?? 0;
    final outstanding = (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
    final totalPay    = (loan['total_payable'] as num?)?.toDouble() ?? 0;
    final frequency   = loan['payment_frequency'] as String? ?? '';
    final payAmt      = (loan['payment_amount'] as num?)?.toDouble() ?? 0;
    final progress    = totalPay > 0 ? (1 - (outstanding / totalPay)).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary500)),
                  const SizedBox(height: 2),
                  Text('₱${_fmt(principal)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(progress * 100).toStringAsFixed(0)}% paid',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('Balance: ₱${_fmt(outstanding)}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:           progress,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.success : AppColors.primary500,
                  ),
                  minHeight: 7,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _InfoChip(icon: Icons.repeat_rounded, label: '${_freqLabel(frequency)} ₱${_fmt(payAmt)}'),
              const SizedBox(width: 8),
              if (status == 'active' || status == 'overdue')
                GestureDetector(
                  onTap: () => context.go(AppConstants.routeLenderPay.replaceAll(':loanId', loan['id'].toString())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Pay Now', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _statusLabel(String s) {
    const map = {'pending': 'Pending', 'under_ci': 'Under CI', 'approved': 'Approved', 'rejected': 'Rejected', 'active': 'Active', 'overdue': 'Overdue', 'completed': 'Completed', 'frozen': 'Frozen'};
    return map[s] ?? s;
  }
  String _freqLabel(String f) {
    const map = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
    return map[f] ?? f;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ApplyLoanBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppConstants.routeLenderApply),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:     AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Need more funds?',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Apply from ₱5,000 up to ₱500,000',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
    );
  }
}

class _LoanCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: List.generate(2, (_) =>
        Container(
          height: 160,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(20)),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.primary100.withValues(alpha: 0.3)),
      ),
    );
  }
}

class _EmptyLoansWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('No active loans', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Apply for a loan to get started', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
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
            Text('Failed to load loans', style: TextStyle(fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}