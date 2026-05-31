// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX 6 — lib/core/router/app_router.dart                               ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  PRIMARY BUG — "Stuck on dashboard / can't navigate anywhere"           ║
// ║                                                                          ║
// ║  ROOT CAUSE:                                                             ║
// ║    The original code did:                                                ║
// ║                                                                          ║
// ║      final appRouterProvider = Provider<GoRouter>((ref) {               ║
// ║        final authState = ref.watch(authStateProvider);   // ← watch!    ║
// ║        return GoRouter(redirect: (ctx, state) { /* uses authState */ }); ║
// ║      });                                                                 ║
// ║                                                                          ║
// ║    Riverpod's Provider re-runs its builder whenever a watched            ║
// ║    dependency changes. So every time authStateProvider emits a new      ║
// ║    value (loading → data, or after ref.invalidate(authStateProvider))   ║
// ║    a BRAND NEW GoRouter instance is created and handed to               ║
// ║    MaterialApp.router.                                                   ║
// ║                                                                          ║
// ║    MaterialApp.router replaces the entire router when it receives a new ║
// ║    GoRouter object, which resets the navigation stack back to            ║
// ║    GoRouter.initialLocation — the splash page. From there the redirect  ║
// ║    sends the user to their dashboard. So every auth-state change sends  ║
// ║    the user back to the dashboard and every in-progress navigation is   ║
// ║    cancelled. This is why both lenders (mobile) and head_managers (web) ║
// ║    appear "stuck" on the dashboard — any attempt to navigate triggers   ║
// ║    an auth state change (riverpod re-evaluates watchers) which recreates ║
// ║    the router which resets navigation.                                   ║
// ║                                                                          ║
// ║  FIX:                                                                   ║
// ║    Create the GoRouter ONCE using a RouterNotifier (ChangeNotifier)     ║
// ║    backed by Riverpod. The GoRouter is configured with                  ║
// ║    refreshListenable: routerNotifier so it re-evaluates the redirect   ║
// ║    function (which calls ref.read, not ref.watch) whenever auth changes ║
// ║    WITHOUT recreating the GoRouter instance. Navigation state is        ║
// ║    preserved; only the redirect guard re-runs.                          ║
// ║                                                                          ║
// ║  SECONDARY FIXES (carried forward from original file):                  ║
// ║    • /web/profile route added (prevents GoRouter 404 crash)             ║
// ║    • Symmetric mobile-route guard for web roles                         ║
// ║    • Auth loading → splash redirect                                     ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// lib/core/router/app_router.dart
// Jireta Loans & Credit Corp. 1996

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../presentation/web/layouts/web_layout.dart';
import '../../presentation/web/pages/auth/web_login_page.dart';
import '../../presentation/web/pages/dashboard/admin_dashboard_page.dart';
import '../../presentation/web/pages/dashboard/employee_dashboard_page.dart';
import '../../presentation/web/pages/employees/employees_page.dart';
import '../../presentation/web/pages/riders/riders_page.dart';
import '../../presentation/web/pages/lenders/lenders_page.dart';
import '../../presentation/web/pages/loans/loans_page.dart';
import '../../presentation/web/pages/collections/collections_page.dart';
import '../../presentation/web/pages/ci/ci_page.dart';
import '../../presentation/web/pages/reports/reports_page.dart';
import '../../presentation/web/pages/settings/settings_page.dart';
import '../../presentation/web/pages/settings/audit_logs_page.dart';
import '../../presentation/mobile/layouts/mobile_layout.dart';
import '../../presentation/mobile/pages/auth/mobile_login_page.dart';
import '../../presentation/mobile/pages/auth/register_page.dart';
import '../../presentation/mobile/pages/auth/forgot_password_page.dart';
import '../../presentation/mobile/pages/dashboard/rider_dashboard_page.dart';
import '../../presentation/mobile/pages/dashboard/lender_dashboard_page.dart';
import '../../presentation/mobile/pages/loans/loan_application_page.dart';
import '../../presentation/mobile/pages/loans/loan_detail_page.dart';
import '../../presentation/mobile/pages/payments/payment_page.dart';
import '../../presentation/mobile/pages/ci/ci_report_page.dart';
import '../../presentation/mobile/pages/collections/collection_page.dart';
import '../../presentation/mobile/pages/profile/profile_page.dart';
import '../../presentation/mobile/pages/notifications/notifications_page.dart';
import '../constants/app_constants.dart';
import 'splash_page.dart';

// ══════════════════════════════════════════════════════════════
// ✅ FIX: RouterNotifier — bridges Riverpod auth state to GoRouter
//         without recreating the GoRouter instance on every change.
// ══════════════════════════════════════════════════════════════

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    // Listen to authStateProvider changes and notify GoRouter to
    // re-run its redirect function — WITHOUT recreating the router.
    _ref.listen<AsyncValue<Map<String, dynamic>?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  /// Called by GoRouter's redirect on every navigation event.
  String? redirect(BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final location = state.matchedLocation;
    final authState = _ref.read(authStateProvider);

    final isSplash = location == AppConstants.routeSplash;
    final isPublic = isSplash ||
        [
          AppConstants.routeWebLogin,
          AppConstants.routeMobileLogin,
          AppConstants.routeRegister,
          AppConstants.routeForgotPassword,
        ].any((r) => location.startsWith(r));

    // ── Unauthenticated ───────────────────────────────────────
    if (session == null && !isPublic) {
      return kIsWeb
          ? AppConstants.routeWebLogin
          : AppConstants.routeMobileLogin;
    }

    if (session != null) {
      // While auth state is loading, hold at splash so we don't
      // flash the wrong page or redirect with a stale/empty role.
      if (authState.isLoading) {
        return isSplash ? null : AppConstants.routeSplash;
      }

      final user = authState.value;
      if (user == null) {
        // DB profile missing or fetch failed → re-login.
        return kIsWeb
            ? AppConstants.routeWebLogin
            : AppConstants.routeMobileLogin;
      }

      final role = user['role'] as String? ?? '';

      // ── Redirect away from auth pages after login ─────────
      if (isPublic && !isSplash) {
        switch (role) {
          case 'head_manager':
          case 'employee':
            return AppConstants.routeWebDashboard;
          case 'rider':
            return AppConstants.routeRiderDashboard;
          case 'lender':
            return AppConstants.routeLenderDashboard;
        }
      }

      // ── Block web-only roles from mobile routes ────────────
      if ((location.startsWith('/rider/') || location.startsWith('/lender/')) &&
          ['head_manager', 'employee'].contains(role)) {
        return AppConstants.routeWebDashboard;
      }

      // ── Block mobile-only roles from web routes ────────────
      if (location.startsWith('/web/') &&
          !['head_manager', 'employee'].contains(role)) {
        return AppConstants.routeMobileLogin;
      }
    }

    return null; // No redirect needed.
  }
}

// ── Provider ────────────────────────────────────────────────
//
// ✅ FIX: appRouterProvider now creates the GoRouter ONCE.
//         authStateProvider is no longer watched here, so the
//         provider never re-runs and the GoRouter is never recreated.
//         Instead, _RouterNotifier.notifyListeners() triggers GoRouter
//         to re-evaluate its redirect without rebuilding the router.

final routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: notifier, // ✅ FIX: notify without recreating
    redirect: notifier.redirect,
    routes: [
      // ── Splash ──────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeSplash,
        name: 'splash',
        builder: (_, __) => const SplashPage(),
      ),

      // ── Auth ────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeWebLogin,
        name: 'web-login',
        builder: (_, __) => const WebLoginPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login-alias',
        redirect: (_, __) => AppConstants.routeMobileLogin,
      ),
      GoRoute(
        path: AppConstants.routeMobileLogin,
        name: 'mobile-login',
        builder: (_, __) => const MobileLoginPage(),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        name: 'register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppConstants.routeForgotPassword,
        name: 'forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),

      // ── Web Shell (Sidebar Layout) ───────────────────────
      ShellRoute(
        builder: (context, state, child) => WebLayout(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeWebDashboard,
            name: 'web-dashboard',
            pageBuilder: (_, state) => _fadePage(
              state,
              Consumer(
                builder: (_, ref, __) {
                  final user = ref.watch(authStateProvider).value;
                  final role = user?['role'] as String? ?? '';
                  return role == 'head_manager'
                      ? const AdminDashboardPage()
                      : const EmployeeDashboardPage();
                },
              ),
            ),
          ),
          GoRoute(
            path: AppConstants.routeWebEmployees,
            name: 'web-employees',
            pageBuilder: (_, state) => _fadePage(state, const EmployeesPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebRiders,
            name: 'web-riders',
            pageBuilder: (_, state) => _fadePage(state, const RidersPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebLenders,
            name: 'web-lenders',
            pageBuilder: (_, state) => _fadePage(state, const LendersPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebLoans,
            name: 'web-loans',
            pageBuilder: (_, state) => _fadePage(state, const LoansPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebCollections,
            name: 'web-collections',
            pageBuilder: (_, state) =>
                _fadePage(state, const CollectionsPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebCI,
            name: 'web-ci',
            pageBuilder: (_, state) => _fadePage(state, const CiPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebReports,
            name: 'web-reports',
            pageBuilder: (_, state) => _fadePage(state, const ReportsPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebSettings,
            name: 'web-settings',
            pageBuilder: (_, state) => _fadePage(state, const SettingsPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebAuditLogs,
            name: 'web-audit-logs',
            pageBuilder: (_, state) => _fadePage(state, const AuditLogsPage()),
          ),
          // ✅ Added missing /web/profile route (prevents GoRouter 404 crash)
          GoRoute(
            path: AppConstants.routeWebProfile,
            name: 'web-profile',
            pageBuilder: (_, state) => _fadePage(state, const WebProfilePage()),
          ),
        ],
      ),

      // ── Rider Shell (Mobile Floating Nav) ────────────────
      ShellRoute(
        builder: (context, state, child) =>
            MobileLayout(role: 'rider', child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeRiderDashboard,
            name: 'rider-dashboard',
            pageBuilder: (_, state) =>
                _slidePage(state, const RiderDashboardPage()),
          ),
          GoRoute(
            path: AppConstants.routeRiderAssignments,
            name: 'rider-assignments',
            pageBuilder: (_, state) =>
                _slidePage(state, const RiderAssignmentsPage()),
          ),
          GoRoute(
            path: AppConstants.routeRiderCI,
            name: 'rider-ci',
            builder: (_, state) => CiReportPage(
              assignmentId: state.pathParameters['assignmentId'] ?? '',
            ),
          ),
          GoRoute(
            path: AppConstants.routeRiderCollect,
            name: 'rider-collect',
            builder: (_, state) => CollectionPage(
              collectionId: state.pathParameters['collectionId'] ?? '',
            ),
          ),
          GoRoute(
            path: AppConstants.routeRiderProfile,
            name: 'rider-profile',
            pageBuilder: (_, state) => _slidePage(state, const ProfilePage()),
          ),
          GoRoute(
            path: AppConstants.routeRiderNotifications,
            name: 'rider-notifications',
            pageBuilder: (_, state) =>
                _slidePage(state, const NotificationsPage()),
          ),
        ],
      ),

      // ── Lender Shell (Mobile Floating Nav) ───────────────
      ShellRoute(
        builder: (context, state, child) =>
            MobileLayout(role: 'lender', child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeLenderDashboard,
            name: 'lender-dashboard',
            pageBuilder: (_, state) =>
                _slidePage(state, const LenderDashboardPage()),
          ),
          GoRoute(
            path: AppConstants.routeLenderApply,
            name: 'lender-apply',
            builder: (_, state) => const LoanApplicationPage(),
          ),
          GoRoute(
            path: AppConstants.routeLenderLoans,
            name: 'lender-loans',
            pageBuilder: (_, state) =>
                _slidePage(state, const LenderLoansListPage()),
          ),
          GoRoute(
            path: AppConstants.routeLenderLoanDetail,
            name: 'lender-loan-detail',
            builder: (_, state) => LoanDetailPage(
              loanId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: AppConstants.routeLenderPay,
            name: 'lender-pay',
            builder: (_, state) => PaymentPage(
              loanId: state.pathParameters['loanId'] ?? '',
            ),
          ),
          GoRoute(
            path: AppConstants.routeLenderDocuments,
            name: 'lender-documents',
            pageBuilder: (_, state) =>
                _slidePage(state, const LenderDocumentsPage()),
          ),
          GoRoute(
            path: AppConstants.routeLenderProfile,
            name: 'lender-profile',
            pageBuilder: (_, state) => _slidePage(state, const ProfilePage()),
          ),
          GoRoute(
            path: AppConstants.routeLenderNotifications,
            name: 'lender-notifications',
            pageBuilder: (_, state) =>
                _slidePage(state, const NotificationsPage()),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(
                kIsWeb
                    ? AppConstants.routeWebLogin
                    : AppConstants.routeMobileLogin,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ── Page Transitions ────────────────────────────────────────

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
      child: child,
    ),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, animation, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

// ── Placeholder pages referenced in router ──────────────────

class RiderAssignmentsPage extends StatelessWidget {
  const RiderAssignmentsPage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage('Assignments');
}

class LenderLoansListPage extends StatelessWidget {
  const LenderLoansListPage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage('My Loans');
}

class LenderDocumentsPage extends StatelessWidget {
  const LenderDocumentsPage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage('Documents');
}

class WebProfilePage extends StatelessWidget {
  const WebProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage('Profile');
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage(this.title);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}
