// lib/core/router/splash_page.dart
// ═══════════════════════════════════════════════════════════════════════════
// FIX SUMMARY (Race Condition — Authenticated Users Sent to Login):
//
// BUG: _navigate() called ref.read(authStateProvider).value which reads the
//   SYNCHRONOUS snapshot of a FutureProvider. Right after the 2-second splash
//   delay the future has likely NOT resolved yet, so .value is null → role is ''
//   → all authenticated users were redirected to the login page instead of their
//   dashboard. This is especially bad on slow connections.
//
// FIX: Use `await ref.read(authStateProvider.future)` to wait for the DB fetch
//   to complete before deciding where to navigate. Added a timeout guard so the
//   splash doesn't hang forever if Supabase is unreachable.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go(kIsWeb
          ? AppConstants.routeWebLogin
          : AppConstants.routeMobileLogin);
      return;
    }

    // FIX ─ Await the future instead of reading a potentially-null snapshot.
    // A 5-second timeout prevents the splash from hanging on network issues.
    Map<String, dynamic>? user;
    try {
      user = await ref
          .read(authStateProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timeout or fetch error → treat as unauthenticated.
      user = null;
    }

    if (!mounted) return;

    final role = user?['role'] as String? ?? '';

    switch (role) {
      case 'head_manager':
      case 'employee':
        context.go(AppConstants.routeWebDashboard);
        break;
      case 'rider':
        context.go(AppConstants.routeRiderDashboard);
        break;
      case 'lender':
        context.go(AppConstants.routeLenderDashboard);
        break;
      default:
        // Unknown or empty role → send to appropriate login page.
        context.go(kIsWeb
            ? AppConstants.routeWebLogin
            : AppConstants.routeMobileLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance,
                color: AppColors.primary600,
                size:  56,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            const Text(
              'Jireta Loans',
              style: TextStyle(
                fontFamily:    'Poppins',
                color:         Colors.white,
                fontSize:      28,
                fontWeight:    FontWeight.w700,
                letterSpacing: -0.5,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 8),

            const Text(
              '& Credit Corp. 1996',
              style: TextStyle(
                fontFamily: 'Poppins',
                color:      Colors.white70,
                fontSize:   14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            )
                .animate(delay: 500.ms)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 8),

            const Text(
              'Sta. Barbara, Pangasinan',
              style: TextStyle(
                fontFamily: 'Poppins',
                color:      Colors.white54,
                fontSize:   12,
              ),
            )
                .animate(delay: 600.ms)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 64),

            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                color:       Colors.white.withValues(alpha: 0.7),
                strokeWidth: 2.5,
              ),
            )
                .animate(delay: 800.ms)
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}