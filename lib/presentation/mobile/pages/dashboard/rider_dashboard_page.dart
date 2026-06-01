// lib/presentation/mobile/pages/dashboard/rider_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

final riderDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return {};

  final db = Supabase.instance.client;

  final user = await db
      .from('users')
      .select('id, first_name, last_name, profile_picture_url')
      .eq('auth_id', authUid)
      .maybeSingle();

  if (user == null) {
    return {'user': {}, 'recentCollections': [], 'pendingCi': [], 'totalCollected': 0.0};
  }

  final userId = user['id'] as String;

  final riderRecord = await db
      .from('riders')
      .select('id, rider_code, vehicle_type, license_number')
      .eq('user_id', userId)
      .maybeSingle();

  if (riderRecord == null) {
    return {
      'user':               user,
      'recentCollections':  <dynamic>[],
      'pendingCi':          <dynamic>[],
      'totalCollected':     0.0,
      'riderInfo':          <String, dynamic>{},
    };
  }

  final riderId = riderRecord['id'] as String;

  final recentCollections = await db
      .from('collections')
      .select(
        'id, collected_amount, collection_status, created_at, '
        'loans!inner(loan_code, lenders!inner(users!inner(first_name, last_name)))',
      )
      .eq('rider_id', riderId)
      .order('created_at', ascending: false)
      .limit(10);

  final totalCollected = (recentCollections as List).fold<double>(
    0,
    (s, c) => s + ((c['collected_amount'] as num?)?.toDouble() ?? 0),
  );

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
    'user':              user,
    'riderInfo':         riderRecord,
    'recentCollections': recentCollections,
    'pendingCi':         pendingCi,
    'totalCollected':    totalCollected,
  };
});

class RiderDashboardPage extends ConsumerWidget {
  const RiderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderDashboardProvider);
    final now       = DateTime.now();
    final greeting  = now.hour < 12 ? 'Good Morning'
        : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: asyncData.when(
        loading: () => const _RiderSkeleton(),
        error:   (e, _) => _ErrorBody(message: e.toString()),
        data: (data) {
          final user           = data['user'] as Map<String, dynamic>? ?? {};
          final riderInfo      = data['riderInfo'] as Map<String, dynamic>? ?? {};
          final recentCols     = data['recentCollections'] as List<dynamic>? ?? [];
          final pendingCi      = data['pendingCi'] as List<dynamic>? ?? [];
          final totalCollected = data['totalCollected'] as double? ?? 0;

          final firstName = user['first_name'] as String? ?? '';
          final lastName  = user['last_name']  as String? ?? '';
          final name      = '$firstName $lastName'.trim().isEmpty
              ? 'Rider'
              : '$firstName $lastName'.trim();
          final riderCode = riderInfo['rider_code'] as String? ?? '';

          return RefreshIndicator(
            color: AppColors.primary500,
            onRefresh: () async => ref.invalidate(riderDashboardProvider),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned:          true,
                  stretch:         true,
                  elevation:       0,
                  backgroundColor: AppColors.primary800,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _RiderHeroHeader(
                      name:        name,
                      firstName:   firstName,
                      riderCode:   riderCode,
                      totalAmount: totalCollected,
                      greeting:    greeting,
                      pendingCi:   pendingCi.length,
                      recentCols:  recentCols.length,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => context.go(AppConstants.routeRiderNotifications),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _StatsRow(
                        totalCollected: totalCollected,
                        pendingCi:      pendingCi.length,
                        recentCols:     recentCols.length,
                      ),

                      const SizedBox(height: 22),

                      _QuickActions(),

                      const SizedBox(height: 26),

                      if (pendingCi.isNotEmpty) ...[
                        _SectionHeader(
                          title:    'Pending CI Visits',
                          count:    pendingCi.length,
                          accentColor: AppColors.warning,
                          onSeeAll: () => context.go(AppConstants.routeRiderAssignments),
                        ),
                        const SizedBox(height: 12),
                        ...pendingCi.take(3).toList().asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CiCard(ci: e.value),
                          ).animate(delay: (60 * e.key).ms).fadeIn(duration: 350.ms).slideX(begin: 0.1),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _SectionHeader(
                        title:       'Recent Collections',
                        count:       recentCols.length,
                        accentColor: AppColors.success,
                        onSeeAll:    () => context.go(AppConstants.routeRiderAssignments),
                      ),
                      const SizedBox(height: 12),

                      if (recentCols.isEmpty)
                        const _EmptyState(
                          icon:    Icons.payments_outlined,
                          message: 'No collections recorded yet',
                          sub:     'Start your route to record collections',
                        )
                      else
                        ...recentCols.take(5).toList().asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CollectionCard(collection: e.value),
                          ).animate(delay: (60 * e.key).ms).fadeIn(duration: 350.ms),
                        ),

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

class _RiderHeroHeader extends StatelessWidget {
  final String name, firstName, riderCode, greeting;
  final double totalAmount;
  final int    pendingCi, recentCols;

  const _RiderHeroHeader({
    required this.name,
    required this.firstName,
    required this.riderCode,
    required this.totalAmount,
    required this.greeting,
    required this.pendingCi,
    required this.recentCols,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF023E6B), Color(0xFF0369a1), AppColors.primary500],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, bottom: 0,
            child: CustomPaint(painter: _HeroBgPainter()),
          ),
          const Positioned(
            right: -10,
            bottom: 30,
            child: _AnimatedMascot(
              assetPath: 'assets/images/rider_dashboard.png',
              size: 170,
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
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.white24, Colors.white10],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white30, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'R',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (riderCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            riderCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Total Collected',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₱${NumberFormat('#,##0.00').format(totalAmount)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins',
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _MiniStat(label: 'CI Tasks', value: '$pendingCi', color: AppColors.warning),
                            const SizedBox(height: 6),
                            _MiniStat(label: 'Collections', value: '$recentCols', color: AppColors.success),
                          ],
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
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _HeroBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.5, 0)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.3, size.width, size.height * 0.5)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path1, paint);

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.7, size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint2);

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 80, circlePaint);

    final circlePaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 60, circlePaint2);
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

class _AnimatedMascotState extends State<_AnimatedMascot> with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _bounceCtrl;
  late AnimationController _glowCtrl;
  late Animation<double>   _floatAnim;
  late Animation<double>   _bounceAnim;
  late Animation<double>   _rotateAnim;
  late Animation<double>   _glowAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _rotateAnim = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
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
      onTapDown:   _onTapDown,
      onTapUp:     _onTapUp,
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
                      width: widget.size + 20,
                      height: widget.size + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: _glowAnim.value * 0.15),
                            blurRadius: 30,
                            spreadRadius: 10,
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
          width:  widget.size,
          height: widget.size,
          fit:    BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.delivery_dining_rounded,
            size:  widget.size * 0.6,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double totalCollected;
  final int    pendingCi, recentCols;
  const _StatsRow({
    required this.totalCollected,
    required this.pendingCi,
    required this.recentCols,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _StatCard(
          label: 'Collections',
          value: '$recentCols',
          icon:  Icons.payments_rounded,
          color: AppColors.success,
          isDark: isDark,
        ).animate(delay: 50.ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85)),
        const SizedBox(width: 10),
        _StatCard(
          label: 'CI Tasks',
          value: '$pendingCi',
          icon:  Icons.assignment_rounded,
          color: AppColors.warning,
          isDark: isDark,
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85)),
        const SizedBox(width: 10),
        _StatCard(
          label: 'On Route',
          value: pendingCi > 0 ? 'Active' : 'Idle',
          icon:  Icons.directions_bike_rounded,
          color: AppColors.primary500,
          isDark: isDark,
        ).animate(delay: 150.ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;
  final bool     isDark;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color:      color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color:      color,
                fontSize:   18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                letterSpacing: -0.3,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color:      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize:   10,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
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
      const _ActionDef('Collections', Icons.payments_rounded,             AppColors.success,    AppConstants.routeRiderAssignments),
      const _ActionDef('CI Reports',  Icons.assignment_outlined,          AppColors.warning,    AppConstants.routeRiderAssignments),
      const _ActionDef('Profile',     Icons.manage_accounts_rounded,      AppColors.accent,     AppConstants.routeRiderProfile),
      const _ActionDef('Alerts',      Icons.notifications_active_rounded, AppColors.primary500, AppConstants.routeRiderNotifications),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < actions.length - 1 ? 10 : 0),
                child: _ActionButton(def: e.value),
              ).animate(delay: (60 * e.key).ms)
                  .fadeIn(duration: 350.ms)
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ActionDef {
  final String   label, route;
  final IconData icon;
  final Color    color;
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

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.def.color.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color:      widget.def.color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset:     const Offset(0, 5),
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
                      widget.def.color.withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
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
                  fontSize:   10,
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

class _CiCard extends StatelessWidget {
  final dynamic ci;
  const _CiCard({required this.ci});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final loan        = ci['loans'] as Map<String, dynamic>? ?? {};
    final lender      = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user        = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final addresses   = (user['addresses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final addr        = addresses.isNotEmpty ? addresses.first : <String, dynamic>{};
    final ciStatus    = (ci['ci_status'] as String?) ?? 'pending';
    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode    = loan['loan_code'] as String? ?? '-';
    final addressStr  = [addr['barangay'], addr['municipality']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');
    final statusColor = ciStatus == 'ongoing' ? AppColors.primary500 : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color:      statusColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.05)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$loanCode${addressStr.isNotEmpty ? ' • $addressStr' : ''}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize:   11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              ciStatus.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   10,
                color:      statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final dynamic collection;
  const _CollectionCard({required this.collection});

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
      try {
        dateLabel = DateFormat('MMM d, y').format(DateTime.parse(createdAt));
      } catch (_) {}
    }

    final statusColor = status == 'completed' ? AppColors.success : AppColors.primary500;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.success.withValues(alpha: 0.15), AppColors.success.withValues(alpha: 0.05)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  borrowerName.isEmpty ? 'Unknown Borrower' : borrowerName,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Loan $loanCode${dateLabel.isNotEmpty ? ' • $dateLabel' : ''}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize:   11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
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
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.success,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String        title;
  final int           count;
  final Color         accentColor;
  final VoidCallback? onSeeAll;
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.accentColor,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color:        accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      accentColor,
                ),
              ),
            ),
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('See all', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message, sub;
  const _EmptyState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColors.primary100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 36, color: AppColors.primary500),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize:   12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RiderSkeleton extends StatelessWidget {
  const _RiderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary500));
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        AppColors.errorLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}