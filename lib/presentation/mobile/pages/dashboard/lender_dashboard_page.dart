// lib/presentation/mobile/pages/dashboard/lender_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/auth_provider.dart';

final lenderActiveLoansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
      .select(
          'id, lender_code, credit_score, risk_level, monthly_income, occupation')
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).value;
    final loans = ref.watch(lenderActiveLoansProvider);
    final lenderInfo = ref.watch(lenderProfileProvider);
    final notifCount = ref.watch(lenderNotifCountProvider).value ?? 0;
    final firstName = user?['first_name'] as String? ?? 'there';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: RefreshIndicator(
        color: AppColors.primary500,
        onRefresh: () async {
          ref.invalidate(lenderActiveLoansProvider);
          ref.invalidate(lenderProfileProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 310,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary800,
              elevation: 0,
              actions: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.go(AppConstants.routeLenderNotifications),
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 26),
                    ),
                    if (notifCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                          child: Text(
                            notifCount > 9 ? '9+' : '$notifCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
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
                  firstName: firstName,
                  loans: loans.value ?? [],
                  lenderInfo: lenderInfo.value ?? {},
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
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'My Loans',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go(AppConstants.routeLenderLoans),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('See all',
                            style:
                                TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  loans.when(
                    loading: () => _LoanCardSkeleton(),
                    error: (_, __) => const _ErrorWidget(),
                    data: (loanList) => loanList.isEmpty
                        ? _EmptyLoansWidget()
                        : Column(
                            children: loanList
                                .asMap()
                                .entries
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _LoanCard(loan: e.value),
                                  )
                                      .animate(delay: (80 * e.key).ms)
                                      .fadeIn(duration: 400.ms)
                                      .slideY(
                                          begin: 0.15,
                                          curve: Curves.easeOutCubic),
                                )
                                .toList(),
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
        .fold<double>(
            0,
            (s, l) =>
                s + ((l['outstanding_balance'] as num?)?.toDouble() ?? 0));

    final lenderCode = lenderInfo['lender_code'] as String? ?? '';
    final creditScore = lenderInfo['credit_score'] as num? ?? 0;
    final riskLevel = lenderInfo['risk_level'] as String? ?? 'medium';
    final riskColor = riskLevel == 'low'
        ? AppColors.success
        : riskLevel == 'high'
            ? AppColors.error
            : AppColors.warning;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF023E6B), Color(0xFF025E99), AppColors.primary500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(painter: _LenderHeroBgPainter()),
          ),
          const Positioned(
            right: -5,
            bottom: 24,
            child: _AnimatedMascot(
              assetPath: 'assets/images/lenders_dashboard.png',
              size: 165,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $firstName 👋',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const Text(
                              'Your Loan Overview',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                      ),
                      if (lenderCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            lenderCode,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: AppColors.warning,
                                        size: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Outstanding Balance',
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₱${_fmt(totalBalance)}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ScoreBadge(score: creditScore.toInt()),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: riskColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${riskLevel.toUpperCase()} RISK',
                                style: TextStyle(
                                  color: riskColor,
                                  fontSize: 9,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 750
        ? AppColors.success
        : score >= 600
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: color, size: 11),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LenderHeroBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.6, 0)
      ..quadraticBezierTo(
          size.width, size.height * 0.4, size.width, size.height * 0.6)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path1, paint);

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
          size.width * 0.4, size.height * 0.8, size.width * 0.6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint2);

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.18), 90, circlePaint);

    final smallCircle = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.08, size.height * 0.75), 55, smallCircle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedMascot extends StatefulWidget {
  final String assetPath;
  final double size;
  const _AnimatedMascot({required this.assetPath, this.size = 160});

  @override
  State<_AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<_AnimatedMascot>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _bounceCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _bounceAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _glowAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _rotateAnim = Tween<double>(begin: -0.035, end: 0.035).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _bounceCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() => _isPressed = true);
    _bounceCtrl.forward();
  }

  void _onTapUp(_) {
    setState(() => _isPressed = false);
    _bounceCtrl.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _bounceCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatCtrl, _bounceCtrl, _glowCtrl]),
        builder: (_, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: Transform.rotate(
              angle: _rotateAnim.value,
              child: Transform.scale(
                scale: _isPressed ? 0.9 : _bounceAnim.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: widget.size + 24,
                      height: widget.size + 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withValues(alpha: _glowAnim.value * 0.12),
                            blurRadius: 35,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            ),
          );
        },
        child: Image.asset(
          widget.assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.account_balance_rounded,
            size: widget.size * 0.6,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _CapabilityCards extends StatelessWidget {
  final Map<String, dynamic> lenderInfo;
  const _CapabilityCards({required this.lenderInfo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditScore = lenderInfo['credit_score'] as num? ?? 0;
    final riskLevel = lenderInfo['risk_level'] as String? ?? 'medium';
    final occupation = lenderInfo['occupation'] as String? ?? 'N/A';

    final riskColor = riskLevel == 'low'
        ? AppColors.success
        : riskLevel == 'high'
            ? AppColors.error
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_rounded,
                    color: AppColors.primary600, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Account Overview',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoTile(
                  label: 'Credit Score',
                  value: '$creditScore',
                  color: AppColors.primary500),
              const SizedBox(width: 10),
              _InfoTile(
                  label: 'Risk Level',
                  value: riskLevel.toUpperCase(),
                  color: riskColor),
              const SizedBox(width: 10),
              const _InfoTile(
                  label: 'Loan Limit', value: '₱500K', color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary50,
                  AppColors.primary100.withValues(alpha: 0.5)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary200.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.work_outline_rounded,
                    size: 15, color: AppColors.primary600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    occupation == 'N/A'
                        ? 'You can apply for loans, make payments, and upload documents.'
                        : 'Occupation: $occupation — Apply for loans & manage payments.',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.primary700),
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
  const _InfoTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  color: color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
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
      const _ActionDef('Apply Loan', Icons.add_card_rounded,
          AppColors.primary500, AppConstants.routeLenderApply),
      const _ActionDef('Pay Now', Icons.payment_rounded, AppColors.success,
          AppConstants.routeLenderLoans),
      const _ActionDef('Documents', Icons.description_rounded,
          AppColors.warning, AppConstants.routeLenderDocuments),
      const _ActionDef('Profile', Icons.manage_accounts_rounded,
          AppColors.accent, AppConstants.routeLenderProfile),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: e.key < actions.length - 1 ? 10 : 0),
                child: _ActionButton(def: e.value),
              ).animate(delay: (60 * e.key).ms).fadeIn(duration: 350.ms).scale(
                  begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
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
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        context.go(widget.def.route);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.def.color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: widget.def.color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.def.color.withValues(alpha: isDark ? 0.25 : 0.15),
                      widget.def.color.withValues(alpha: isDark ? 0.15 : 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.def.icon, color: widget.def.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                widget.def.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                textAlign: TextAlign.center,
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = loan['loan_status'] as String? ?? '';
    final statusColor = AppColors.loanStatusColor(status);
    final code = loan['loan_code'] as String? ?? '';
    final principal = (loan['principal_amount'] as num?)?.toDouble() ?? 0;
    final outstanding = (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
    final totalPay = (loan['total_payable'] as num?)?.toDouble() ?? 0;
    final frequency = loan['payment_frequency'] as String? ?? '';
    final payAmt = (loan['payment_amount'] as num?)?.toDouble() ?? 0;
    final progress =
        totalPay > 0 ? (1 - (outstanding / totalPay)).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              color: statusColor.withValues(alpha: isDark ? 0.08 : 0.04),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₱${_fmt(principal)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded,
                              size: 13, color: AppColors.success),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% paid',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Balance: ₱${_fmt(outstanding)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? AppColors.success
                          : AppColors.primary500,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.repeat_rounded,
                        label: '${_freqLabel(frequency)} ₱${_fmt(payAmt)}'),
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (status == 'active' || status == 'overdue')
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.go(
                          AppConstants.routeLenderPay
                              .replaceAll(':loanId', loan['id'].toString()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary500.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _statusLabel(String s) {
    const map = {
      'pending': 'Pending',
      'under_ci': 'Under CI',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'active': 'Active',
      'overdue': 'Overdue',
      'completed': 'Completed',
      'frozen': 'Frozen',
    };
    return map[s] ?? s;
  }

  String _freqLabel(String f) {
    const map = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
    return map[f] ?? f;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyLoanBanner extends StatefulWidget {
  @override
  State<_ApplyLoanBanner> createState() => _ApplyLoanBannerState();
}

class _ApplyLoanBannerState extends State<_ApplyLoanBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) =>
          Transform.scale(scale: _pulseAnim.value, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go(AppConstants.routeLenderApply),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primary700,
                AppColors.primary500,
                AppColors.accent
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary500.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need more funds?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apply from ₱5,000 up to ₱500,000',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Text(
                        'Apply Now →',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
      ),
    );
  }
}

class _LoanCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: AppColors.primary100.withValues(alpha: 0.3),
            ),
      ),
    );
  }
}

class _EmptyLoansWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: AppColors.primary500),
          ),
          const SizedBox(height: 14),
          const Text(
            'No active loans',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Apply for a loan to get started',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
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
      padding: const EdgeInsets.all(28),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 42),
            SizedBox(height: 10),
            Text(
              'Failed to load loans',
              style:
                  TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
