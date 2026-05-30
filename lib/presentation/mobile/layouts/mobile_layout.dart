// lib/presentation/mobile/layouts/mobile_layout.dart
// ═══════════════════════════════════════════════════════════════════════════
// FIXES IN THIS FILE:
//
// BUG 1 — _selectedIndex not synced with GoRouter location (UX + functional)
//   ORIGINAL: _selectedIndex was stored as state and only updated on tap.
//   If a page navigated programmatically (e.g. rider_dashboard_page.dart
//   called context.go(AppConstants.routeRiderAssignments)), _selectedIndex
//   stayed at 0 (Home) even though the user was on Assignments.
//   Worse: when paired with Bug #1 in app_router.dart (GoRouter recreation),
//   the _selectedIndex was always reset to 0 after every auth-state reload,
//   making the nav appear permanently stuck on Home.
//   FIX: Remove _selectedIndex from state entirely. Compute the active tab
//   index on every build by comparing GoRouterState.of(context).matchedLocation
//   against each nav item's route. This is always accurate regardless of how
//   navigation happened (tap, programmatic, back-gesture, etc.).
//
// BUG 2 — Dead _fabController AnimationController (memory leak)
//   ORIGINAL: _fabController was created in initState() and disposed in
//   dispose(), but was NEVER referenced in build() or anywhere else.
//   An AnimationController that is created but never passed to an Animation
//   still allocates a Ticker on the vsync mixin, consuming resources for
//   the entire lifetime of the widget.
//   FIX: Remove _fabController, _fabController.dispose(), and the
//   TickerProviderStateMixin (replaced with SingleTickerProviderStateMixin
//   since no AnimationController is needed here anymore).
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class MobileLayout extends ConsumerWidget {
  final Widget child;
  final String role; // 'rider' | 'lender'

  const MobileLayout({
    super.key,
    required this.child,
    required this.role,
  });

  // FIX BUG 1: Nav definitions are now static so they can be used in the
  // build method to compute the active index from the current route.
  static const List<_NavDef> _riderNav = [
    _NavDef(icon: Icons.home_rounded,          label: 'Home',        route: AppConstants.routeRiderDashboard),
    _NavDef(icon: Icons.assignment_rounded,    label: 'Assignments', route: AppConstants.routeRiderAssignments),
    _NavDef(icon: Icons.notifications_rounded, label: 'Alerts',      route: AppConstants.routeRiderNotifications),
    _NavDef(icon: Icons.person_rounded,        label: 'Profile',     route: AppConstants.routeRiderProfile),
  ];

  static const List<_NavDef> _lenderNav = [
    _NavDef(icon: Icons.home_rounded,                   label: 'Home',     route: AppConstants.routeLenderDashboard),
    _NavDef(icon: Icons.account_balance_wallet_rounded, label: 'Loans',    route: AppConstants.routeLenderLoans),
    _NavDef(icon: Icons.notifications_rounded,          label: 'Alerts',   route: AppConstants.routeLenderNotifications),
    _NavDef(icon: Icons.person_rounded,                 label: 'Profile',  route: AppConstants.routeLenderProfile),
  ];

  List<_NavDef> get _navItems => role == 'rider' ? _riderNav : _lenderNav;

  // FIX BUG 1: Compute active index from the current GoRouter location
  // instead of relying on a stale _selectedIndex state field.
  int _activeIndex(String location) {
    // Walk from the end so more-specific routes take precedence.
    for (var i = _navItems.length - 1; i >= 0; i--) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0; // Default to Home if no match.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    // FIX BUG 1: Read the location here in build so the index is always fresh.
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _activeIndex(location);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: child,
      extendBody: true,
      bottomNavigationBar: _FloatingBottomNav(
        items:         _navItems,
        selectedIndex: selected,
        onTap: (index) => context.go(_navItems[index].route),
        isDark:        isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Floating Bottom Nav
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// Nav Button
// ─────────────────────────────────────────────────────────────────────────

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
      onTapDown:  (_) => _ctrl.forward(),
      onTapUp:    (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      behavior:  HitTestBehavior.opaque,
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

// ─────────────────────────────────────────────────────────────────────────
// Nav Definition
// ─────────────────────────────────────────────────────────────────────────

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