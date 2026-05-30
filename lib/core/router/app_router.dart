// lib/core/router/app_router.dart
// Jireta Loans & Credit Corp. 1996
// ═══════════════════════════════════════════════════════════════════════════
// FIX SUMMARY:
//
// BUG 1 (Missing mobile-route guard for web-only roles):
//   The original guard only blocked riders/lenders from /web/ routes.
//   It did NOT block head_manager/employee from /rider/ or /lender/ routes,
//   so a web user navigating manually to a mobile path would see mobile UI.
//   FIX: Added symmetric guard — if on /rider/ or /lender/ and role is a web
//        role, redirect to /web/dashboard.
//
// BUG 2 (Missing /web/profile route — runtime GoRouter crash):
//   WebTopBar calls context.go(AppConstants.routeWebProfile) but no route for
//   '/web/profile' existed in the router. Clicking the profile icon caused a
//   GoRouter 404 error page.
//   FIX: Added GoRoute for '/web/profile' inside the Web ShellRoute.
//        A lightweight ProfilePage placeholder is included; replace with your
//        real implementation when ready.
//
// BUG 3 (Auth loading state not handled in redirect):
//   When authState is still AsyncLoading, authState.value is null and the
//   redirect returned null (no redirect). This briefly allowed access to
//   protected routes before the user data loaded.
//   FIX: When session exists but user is still loading, redirect to splash so
//        the user waits for auth to resolve cleanly.
// ═══════════════════════════════════════════════════════════════════════════

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

// ── Providers ────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final session  = Supabase.instance.client.auth.currentSession;
      final location = state.matchedLocation;

      final publicRoutes = [
        AppConstants.routeSplash,
        AppConstants.routeWebLogin,
        AppConstants.routeMobileLogin,
        AppConstants.routeRegister,
        AppConstants.routeForgotPassword,
      ];

      final isPublic = publicRoutes.any((r) => location.startsWith(r));

      // ── Unauthenticated: send to correct login page ───────
      if (session == null && !isPublic) {
        return kIsWeb
            ? AppConstants.routeWebLogin
            : AppConstants.routeMobileLogin;
      }

      if (session != null) {
        // FIX 3 ─ If session exists but user is still loading, wait at splash.
        if (authState.isLoading) {
          return location == AppConstants.routeSplash
              ? null // Already on splash, stay.
              : AppConstants.routeSplash;
        }

        final user = authState.value;
        if (user == null) {
          // Auth fetch returned null (DB profile missing) → re-login.
          return kIsWeb
              ? AppConstants.routeWebLogin
              : AppConstants.routeMobileLogin;
        }

        final role = user['role'] as String? ?? '';

        // ── Redirect from auth pages after login ─────────
        if (isPublic && location != AppConstants.routeSplash) {
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

        // FIX 1a ─ Block web-only roles from mobile routes.
        if ((location.startsWith('/rider/') ||
                location.startsWith('/lender/')) &&
            ['head_manager', 'employee'].contains(role)) {
          return AppConstants.routeWebDashboard;
        }

        // FIX 1b ─ Block mobile-only roles from web routes (kept from original).
        if (location.startsWith('/web/') &&
            !['head_manager', 'employee'].contains(role)) {
          return AppConstants.routeMobileLogin;
        }
      }

      return null;
    },
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
            pageBuilder: (_, state) =>
                _fadePage(state, const EmployeesPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebRiders,
            name: 'web-riders',
            pageBuilder: (_, state) => _fadePage(state, const RidersPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebLenders,
            name: 'web-lenders',
            pageBuilder: (_, state) =>
                _fadePage(state, const LendersPage()),
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
            pageBuilder: (_, state) =>
                _fadePage(state, const ReportsPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebSettings,
            name: 'web-settings',
            pageBuilder: (_, state) =>
                _fadePage(state, const SettingsPage()),
          ),
          GoRoute(
            path: AppConstants.routeWebAuditLogs,
            name: 'web-audit-logs',
            pageBuilder: (_, state) =>
                _fadePage(state, const AuditLogsPage()),
          ),
          // FIX 2 ─ Added missing /web/profile route.
          GoRoute(
            path: AppConstants.routeWebProfile,
            name: 'web-profile',
            pageBuilder: (_, state) =>
                _fadePage(state, const WebProfilePage()),
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
            pageBuilder: (_, state) =>
                _slidePage(state, const ProfilePage()),
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
            pageBuilder: (_, state) =>
                _slidePage(state, const ProfilePage()),
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
          ],
        ),
      ),
    ),
  );
});

// ── Page Transitions ────────────────────────────────────────

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key:   state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
      child:   child,
    ),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key:   state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, animation, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end:   Offset.zero,
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

// FIX 2 ─ WebProfilePage added so /web/profile no longer crashes.
// Replace with your real web profile implementation when ready.
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