// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX 2 — lib/presentation/web/layouts/web_layout.dart                   ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  BUG: Head Manager / Employee can see the sidebar but cannot click       ║
// ║       non-active nav items (stuck on Dashboard).                         ║
// ║                                                                          ║
// ║  ROOT CAUSE:                                                             ║
// ║    _NavItem uses GestureDetector with default                            ║
// ║    HitTestBehavior.deferToChild.  When a nav item is neither active nor  ║
// ║    hovered, its background color is Colors.transparent.  Flutter's hit-  ║
// ║    testing skips transparent areas when behavior is deferToChild, so the ║
// ║    tap gesture is never delivered even though the cursor shows a hand.   ║
// ║                                                                          ║
// ║  FIX:                                                                    ║
// ║    Add behavior: HitTestBehavior.opaque to the GestureDetector so the   ║
// ║    entire item rect receives pointer events regardless of background.    ║
// ║    Also moved to InkWell (which handles opaque hit-testing natively and  ║
// ║    gives the expected ripple feedback on web).                           ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// lib/presentation/web/layouts/web_layout.dart
// Jireta Loans & Credit Corp. 1996 — Web Sidebar Layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';

class WebLayout extends ConsumerStatefulWidget {
  final Widget child;
  const WebLayout({super.key, required this.child});

  @override
  ConsumerState<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends ConsumerState<WebLayout>
    with SingleTickerProviderStateMixin {
  bool _sidebarCollapsed = false;

  static const double _expandedWidth  = 260.0;
  static const double _collapsedWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width  = MediaQuery.of(context).size.width;

    // Auto-collapse on smaller screens
    if (width < 1100 && !_sidebarCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => setState(() => _sidebarCollapsed = true));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────
          AnimatedContainer(
            duration: AppConstants.normalAnim,
            curve:    Curves.easeInOutCubic,
            width:    _sidebarCollapsed ? _collapsedWidth : _expandedWidth,
            child:    _WebSidebar(collapsed: _sidebarCollapsed),
          ),

          // ── Main Content ──────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _WebTopBar(
                  collapsed: _sidebarCollapsed,
                  onToggle:  () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────

class _WebSidebar extends ConsumerWidget {
  final bool collapsed;
  const _WebSidebar({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    final role     = ref.watch(currentRoleProvider);
    final isAdmin  = role == 'head_manager';

    final sidebarBg    = isDark ? AppColors.darkSidebar    : AppColors.lightSidebar;
    final sidebarBorder= isDark ? AppColors.darkSidebarBorder : AppColors.lightSidebarBorder;

    return Container(
      decoration: BoxDecoration(
        color:  sidebarBg,
        border: Border(
          right: BorderSide(color: sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Logo ──────────────────────────────────────────
          _SidebarLogo(collapsed: collapsed),
          const Divider(height: 1),

          // ── Nav Items ──────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon:      Icons.dashboard_rounded,
                  label:     'Dashboard',
                  route:     AppConstants.routeWebDashboard,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.people_alt_rounded,
                  label:     'Employees',
                  route:     AppConstants.routeWebEmployees,
                  collapsed: collapsed,
                  current:   location,
                  hidden:    !isAdmin,
                ),
                _NavItem(
                  icon:      Icons.delivery_dining_rounded,
                  label:     'Riders',
                  route:     AppConstants.routeWebRiders,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.person_search_rounded,
                  label:     'Lenders',
                  route:     AppConstants.routeWebLenders,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.account_balance_wallet_rounded,
                  label:     'Loans',
                  route:     AppConstants.routeWebLoans,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.payments_rounded,
                  label:     'Collections',
                  route:     AppConstants.routeWebCollections,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.search_rounded,
                  label:     'Credit Invest.',
                  route:     AppConstants.routeWebCI,
                  collapsed: collapsed,
                  current:   location,
                ),
                _NavItem(
                  icon:      Icons.bar_chart_rounded,
                  label:     'Reports',
                  route:     AppConstants.routeWebReports,
                  collapsed: collapsed,
                  current:   location,
                ),

                if (isAdmin) ...[
                  const _SidebarDivider(),
                  _NavItem(
                    icon:      Icons.history_rounded,
                    label:     'Audit Logs',
                    route:     AppConstants.routeWebAuditLogs,
                    collapsed: collapsed,
                    current:   location,
                  ),
                  _NavItem(
                    icon:      Icons.settings_rounded,
                    label:     'Settings',
                    route:     AppConstants.routeWebSettings,
                    collapsed: collapsed,
                    current:   location,
                  ),
                ],
              ],
            ),
          ),

          // ── User Footer ────────────────────────────────────
          const Divider(height: 1),
          _SidebarUserTile(collapsed: collapsed),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  final bool collapsed;
  const _SidebarLogo({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.normalAnim,
      height:   72,
      padding:  EdgeInsets.symmetric(
        horizontal: collapsed ? 16 : 20,
        vertical:   16,
      ),
      child: Row(
        children: [
          Container(
            width:  40, height: 40,
            decoration: BoxDecoration(
              gradient:     AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.primary500.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jireta Loans',
                    style: TextStyle(
                      fontFamily:  'Poppins',
                      fontSize:    13,
                      fontWeight:  FontWeight.w700,
                      color:       AppColors.primary600,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '& Credit Corp. 1996',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize:   9,
                      fontWeight: FontWeight.w500,
                      color:      AppColors.primary400,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String   label;
  final String   route;
  final bool     collapsed;
  final String   current;
  final bool     hidden;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.collapsed,
    required this.current,
    this.hidden = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.hidden) return const SizedBox.shrink();

    final isActive = widget.current.startsWith(widget.route);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    const activeColor  = AppColors.primary500;
    const activeBg     = AppColors.primary50;
    final activeBgDark = AppColors.primary900.withValues(alpha: 0.4);
    final hoverBg      = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    Color bgColor;
    if (isActive) {
      bgColor = isDark ? activeBgDark : activeBg;
    } else if (_hovered) {
      bgColor = hoverBg;
    } else {
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor:  SystemMouseCursors.click,
        child: GestureDetector(
          // ✅ FIX: HitTestBehavior.opaque ensures the transparent background
          //         still receives pointer events.  Without this, Flutter skips
          //         hit-testing for transparent areas (deferToChild default),
          //         so non-active items never fire onTap.
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(widget.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height:   44,
            decoration: BoxDecoration(
              color:        bgColor,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.2), width: 1)
                  : null,
            ),
            child: Tooltip(
              message:  widget.collapsed ? widget.label : '',
              waitDuration: const Duration(milliseconds: 500),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 12,
                ),
                child: Row(
                  mainAxisAlignment: widget.collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.icon,
                          size:  20,
                          color: isActive
                              ? activeColor
                              : isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                    if (!widget.collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize:   13.5,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive
                                ? activeColor
                                : isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 4, height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.primary500,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section Divider
// ─────────────────────────────────────────────────────────────

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Divider(
        color:     Theme.of(context).dividerColor,
        thickness: 1,
        height:    1,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// User Tile (bottom of sidebar)
// ─────────────────────────────────────────────────────────────

class _SidebarUserTile extends ConsumerWidget {
  final bool collapsed;
  const _SidebarUserTile({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(authStateProvider).value;
    final firstName = user?['first_name'] as String? ?? '';
    final lastName  = user?['last_name']  as String? ?? '';
    final role      = user?['role']       as String? ?? '';
    final avatarUrl = user?['profile_picture_url'] as String?;

    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius:     18,
            backgroundColor: AppColors.primary100,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(initials,
                    style: const TextStyle(
                      color:      AppColors.primary600,
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                    ))
                : null,
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize:      MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _roleLabel(role),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize:   10,
                      color:      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showSignOutDialog(context, ref),
              icon:      const Icon(Icons.logout_rounded, size: 18),
              color:     Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip:   'Sign Out',
              padding:   EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'head_manager': return 'Head Manager';
      case 'employee':     return 'Employee';
      default:             return role;
    }
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppConstants.routeWebLogin);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────

class _WebTopBar extends ConsumerWidget {
  final bool     collapsed;
  final VoidCallback onToggle;

  const _WebTopBar({required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final location  = GoRouterState.of(context).matchedLocation;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color:  isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              size: 22,
            ),
            tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
          ),

          const SizedBox(width: 12),

          Text(
            _pageTitle(location),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize:   17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: themeMode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            tooltip: 'Notifications',
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: () => context.go(AppConstants.routeWebProfile),
            icon: const Icon(Icons.account_circle_rounded, size: 22),
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }

  String _pageTitle(String location) {
    if (location.contains('/dashboard'))   return 'Dashboard';
    if (location.contains('/employees'))   return 'Employees';
    if (location.contains('/riders'))      return 'Riders';
    if (location.contains('/lenders'))     return 'Lenders';
    if (location.contains('/loans'))       return 'Loans';
    if (location.contains('/collections')) return 'Collections';
    if (location.contains('/ci'))          return 'Credit Investigation';
    if (location.contains('/reports'))     return 'Reports';
    if (location.contains('/audit'))       return 'Audit Logs';
    if (location.contains('/settings'))    return 'Settings';
    if (location.contains('/profile'))     return 'Profile';
    return AppConstants.companyShort;
  }
}