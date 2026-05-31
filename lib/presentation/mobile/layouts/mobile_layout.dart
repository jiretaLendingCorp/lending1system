// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX 5 — lib/presentation/mobile/layouts/mobile_layout.dart             ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  BUG: Bottom nav always shows "Home" selected even after tapping other  ║
// ║       tabs. Tapping tabs appears to do nothing visually.                ║
// ║                                                                          ║
// ║  ROOT CAUSE:                                                             ║
// ║    _selectedIndex is a local int starting at 0. After the GoRouter      ║
// ║    redirects the user (e.g. from the splash page directly to             ║
// ║    /lender/loans), _selectedIndex is never updated. The nav bar always  ║
// ║    highlights Home (index 0) regardless of the current page.            ║
// ║                                                                          ║
// ║    Also, tapping a tab calls context.go() BUT if the GoRouter is being  ║
// ║    recreated frequently (see FIX6), the go() call gets swallowed and    ║
// ║    the page doesn't change.                                              ║
// ║                                                                          ║
// ║  FIX:                                                                   ║
// ║    Derive the selected index from GoRouterState.of(context).            ║
// ║    matchedLocation instead of tracking it locally. This keeps the nav  ║
// ║    in sync with whatever the router says the current page is, including ║
// ║    deep links and redirects.                                             ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// lib/presentation/mobile/layouts/mobile_layout.dart
// Jireta Loans & Credit Corp. 1996 — Mobile Floating Bottom Nav

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class MobileLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String role; // 'rider' | 'lender'

  const MobileLayout({
    super.key,
    required this.child,
    required this.role,
  });

  @override
  ConsumerState<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<MobileLayout>
    with TickerProviderStateMixin {
  late AnimationController _fabController;

  final List<_NavDef> _riderNav = const [
    _NavDef(icon: Icons.home_rounded,          label: 'Home',        route: AppConstants.routeRiderDashboard),
    _NavDef(icon: Icons.assignment_rounded,    label: 'Assignments', route: AppConstants.routeRiderAssignments),
    _NavDef(icon: Icons.notifications_rounded, label: 'Alerts',      route: AppConstants.routeRiderNotifications),
    _NavDef(icon: Icons.person_rounded,        label: 'Profile',     route: AppConstants.routeRiderProfile),
  ];

  final List<_NavDef> _lenderNav = const [
    _NavDef(icon: Icons.home_rounded,                    label: 'Home',    route: AppConstants.routeLenderDashboard),
    _NavDef(icon: Icons.account_balance_wallet_rounded,  label: 'Loans',   route: AppConstants.routeLenderLoans),
    _NavDef(icon: Icons.notifications_rounded,           label: 'Alerts',  route: AppConstants.routeLenderNotifications),
    _NavDef(icon: Icons.person_rounded,                  label: 'Profile', route: AppConstants.routeLenderProfile),
  ];

  List<_NavDef> get _navItems =>
      widget.role == 'rider' ? _riderNav : _lenderNav;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // ✅ FIX: Derive the selected index from the current route location
  //         instead of tracking it locally. This keeps the nav bar in sync
  //         even after GoRouter-driven redirects (login → dashboard, etc.).
  int _selectedIndex(String location) {
    // Find the nav item whose route most specifically matches the current path.
    // Iterate in reverse so longer/more-specific routes take precedence.
    for (int i = _navItems.length - 1; i >= 0; i--) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0; // default: Home
  }

  void _onNavTap(int index) {
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    // ✅ FIX: Read current location from GoRouter state to derive active tab
    final location = GoRouterState.of(context).matchedLocation;
    final selIdx   = _selectedIndex(location);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: _FloatingBottomNav(
        items:         _navItems,
        selectedIndex: selIdx,      // ✅ FIX: router-driven, not local state
        onTap:         _onNavTap,
        isDark:        isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Floating Bottom Nav
// ─────────────────────────────────────────────────────────────

class _FloatingBottomNav extends StatelessWidget {
  final List<_NavDef>      items;
  final int                selectedIndex;
  final void Function(int) onTap;
  final bool               isDark;

  const _FloatingBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color:        isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:      isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : AppColors.primary500.withValues(alpha: 0.12),
                blurRadius: 24,
                offset:     const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color:      isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item  = entry.value;
              return Expanded(
                child: _NavButton(
                  item:     item,
                  selected: selectedIndex == index,
                  onTap:    () => onTap(index),
                  isDark:   isDark,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 2.0, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────
// Nav Button
// ─────────────────────────────────────────────────────────────

class _NavButton extends StatefulWidget {
  final _NavDef  item;
  final bool     selected;
  final VoidCallback onTap;
  final bool     isDark;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return GestureDetector(
      // ✅ FIX: HitTestBehavior.opaque so transparent areas still receive taps
      behavior:    HitTestBehavior.opaque,
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeOutCubic,
          margin:   const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary500
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.item.icon,
                  key:   ValueKey(widget.selected),
                  size:  22,
                  color: widget.selected ? Colors.white : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize:   10,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color:      widget.selected ? Colors.white : inactiveColor,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Nav Definition
// ─────────────────────────────────────────────────────────────

class _NavDef {
  final IconData icon;
  final String   label;
  final String   route;

  const _NavDef({
    required this.icon,
    required this.label,
    required this.route,
  });
}