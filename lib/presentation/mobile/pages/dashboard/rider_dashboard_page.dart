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
          final user          = data['user'] as Map<String, dynamic>? ?? {};
          final riderInfo     = data['riderInfo'] as Map<String, dynamic>? ?? {};
          final recentCols    = data['recentCollections'] as List<dynamic>? ?? [];
          final pendingCi     = data['pendingCi'] as List<dynamic>? ?? [];
          final totalCollected= data['totalCollected'] as double? ?? 0;

          final firstName = user['first_name'] as String? ?? '';
          final lastName  = user['last_name']  as String? ?? '';
          final name      = '$firstName $lastName'.trim().isEmpty ? 'Rider' : '$firstName $lastName'.trim();
          final riderCode = riderInfo['rider_code'] as String? ?? '';

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(riderDashboardProvider),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned:  true,
                  stretch: true,
                  backgroundColor: AppColors.primary700,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _RiderHeroHeader(
                      name:         name,
                      firstName:    firstName,
                      riderCode:    riderCode,
                      totalAmount:  totalCollected,
                      greeting:     greeting,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon:      const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => context.go(AppConstants.routeRiderNotifications),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _CapabilityBanner(pendingCi: pendingCi.length, recentCols: recentCols.length),

                      const SizedBox(height: 20),

                      _QuickActions(),

                      const SizedBox(height: 24),

                      if (pendingCi.isNotEmpty) ...[
                        _SectionHeader(
                          title:    'Pending CI Visits',
                          count:    pendingCi.length,
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
                        title:    'Recent Collections',
                        count:    recentCols.length,
                        onSeeAll: () => context.go(AppConstants.routeRiderAssignments),
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

  const _RiderHeroHeader({
    required this.name,
    required this.firstName,
    required this.riderCode,
    required this.totalAmount,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary800, AppColors.primary600],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top:   -20,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/rider_hero.png',
                width:  220,
                height: 220,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 220, height: 220,
                  child: Icon(Icons.delivery_dining, size: 180, color: Colors.white),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color:        Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'R',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins')),
                            Text(name,     style: const TextStyle(color: Colors.white,   fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                          ],
                        ),
                      ),
                      if (riderCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(riderCode, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Collected', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins')),
                              const SizedBox(height: 4),
                              Text(
                                '₱${NumberFormat('#,##0.00').format(totalAmount)}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 22),
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

class _CapabilityBanner extends StatelessWidget {
  final int pendingCi, recentCols;
  const _CapabilityBanner({required this.pendingCi, required this.recentCols});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          const Text('Your Responsibilities', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _CapChip(icon: Icons.assignment_turned_in_rounded, label: 'CI Visits',    color: AppColors.warning,  count: pendingCi),
              const SizedBox(width: 10),
              _CapChip(icon: Icons.payments_rounded,             label: 'Collections',  color: AppColors.success,  count: recentCols),
              const SizedBox(width: 10),
              const _CapChip(icon: Icons.map_rounded,                  label: 'Route',        color: AppColors.primary500, count: null),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _CapChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final int?     count;
  const _CapChip({required this.icon, required this.label, required this.color, this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            if (count != null)
              Text('$count', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Poppins'), textAlign: TextAlign.center),
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
      const _ActionDef('Collections', Icons.payments_rounded,            AppColors.success,    AppConstants.routeRiderAssignments),
      const _ActionDef('CI Reports',  Icons.assignment_outlined,         AppColors.warning,    AppConstants.routeRiderAssignments),
      const _ActionDef('Profile',     Icons.manage_accounts_rounded,     AppColors.accent,     AppConstants.routeRiderProfile),
      const _ActionDef('Alerts',      Icons.notifications_active_rounded,AppColors.primary500, AppConstants.routeRiderNotifications),
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

class _CiCard extends StatelessWidget {
  final dynamic ci;
  const _CiCard({required this.ci});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final loan       = ci['loans'] as Map<String, dynamic>? ?? {};
    final lender     = (loan['lenders'] as Map?)?.cast<String, dynamic>() ?? {};
    final user       = (lender['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final addresses  = (user['addresses'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final addr       = addresses.isNotEmpty ? addresses.first : <String,dynamic>{};
    final ciStatus   = (ci['ci_status'] as String?) ?? 'pending';

    final borrowerName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final loanCode     = loan['loan_code'] as String? ?? '-';
    final addressStr   = [addr['barangay'], addr['municipality']]
        .where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final statusColor = ciStatus == 'ongoing' ? AppColors.primary500 : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        statusColor.withValues(alpha: 0.1),
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
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(ciStatus.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        AppColors.success.withValues(alpha: 0.1),
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
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₱${NumberFormat('#,##0.00').format(amt)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: statusColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int    count;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, required this.count, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary100, borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary600)),
            ),
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RiderSkeleton extends StatelessWidget {
  const _RiderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Something went wrong', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          Text(message, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}