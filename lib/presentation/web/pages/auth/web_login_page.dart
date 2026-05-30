// lib/presentation/web/pages/auth/web_login_page.dart
// Jireta Loans & Credit Corp. 1996 — Web Login

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';

class WebLoginPage extends ConsumerStatefulWidget {
  const WebLoginPage({super.key});

  @override
  ConsumerState<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends ConsumerState<WebLoginPage> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool  _obscure   = true;
  bool  _loading   = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    final ok = await ref.read(authNotifierProvider.notifier).signInWeb(
      email:    _emailCtrl.text,
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      context.go(AppConstants.routeWebDashboard);
    } else {
      final err = ref.read(authNotifierProvider).error;
      setState(() => _error = err?.toString() ?? 'Login failed. Please check your credentials.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ───────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkBackground, AppColors.primary900.withValues(alpha: 0.4)]
                    : [AppColors.primary50, AppColors.primary100],
              ),
            ),
          ),

          // ── Decorative circles ────────────────────────────
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary500.withValues(alpha: isDark ? 0.08 : 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: isDark ? 0.06 : 0.10),
              ),
            ),
          ),

          // ── Theme toggle ──────────────────────────────────
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: isDark ? 'Light mode' : 'Dark mode',
            ),
          ),

          // ── Center content ────────────────────────────────
          Center(
            child: SingleChildScrollView(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left branding panel (hidden on small screens)
                  if (size.width > 900)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(64),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:  MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                gradient:     AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppColors.elevatedShadow,
                              ),
                              child: const Icon(Icons.account_balance, color: Colors.white, size: 40),
                            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                            const SizedBox(height: 32),

                            Text(
                              AppConstants.companyName,
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color:       isDark ? Colors.white : AppColors.primary800,
                                fontWeight:  FontWeight.w800,
                                height:      1.2,
                              ),
                            ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideX(begin: -0.2),

                            const SizedBox(height: 16),

                            Text(
                              AppConstants.companyTagline,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize:   16,
                                color:      isDark ? AppColors.darkTextSecondary : AppColors.primary600,
                                fontWeight: FontWeight.w400,
                              ),
                            ).animate(delay: 400.ms).fadeIn(duration: 500.ms),

                            const SizedBox(height: 48),

                            // Feature bullets
                            ...[
                              ('🔒', 'Enterprise-grade security'),
                              ('⚡', 'Real-time monitoring'),
                              ('📊', 'Advanced analytics'),
                              ('📱', 'Multi-platform support'),
                            ].map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Text(f.$1, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 16),
                                  Text(
                                    f.$2,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize:   14,
                                      color:      isDark ? AppColors.darkTextSecondary : AppColors.primary700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideX(begin: -0.1)),
                          ],
                        ),
                      ),
                    ),

                  // ── Login Card ─────────────────────────────
                  Container(
                    width:  440,
                    margin: const EdgeInsets.all(24),
                    child: _LoginCard(
                      formKey:   _formKey,
                      emailCtrl: _emailCtrl,
                      passCtrl:  _passCtrl,
                      obscure:   _obscure,
                      loading:   _loading,
                      error:     _error,
                      onObscureToggle: () => setState(() => _obscure = !_obscure),
                      onSubmit:  _submit,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms)
                   .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Login Card
// ─────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool     obscure;
  final bool     loading;
  final String?  error;
  final VoidCallback onObscureToggle;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onObscureToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.primary500.withValues(alpha: 0.08),
            blurRadius: 40,
            offset:     const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Welcome back',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your admin portal',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   14,
                color:      Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Email
            TextFormField(
              controller:   emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect:  false,
              decoration:   const InputDecoration(
                labelText:   'Email address',
                prefixIcon:  Icon(Icons.email_outlined),
                hintText:    'admin@jiretaloans.com',
              ),
              validator: AppValidators.emailAdmin,
              onFieldSubmitted: (_) => onSubmit(),
            ),

            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller:  passCtrl,
              obscureText: obscure,
              decoration:  InputDecoration(
                labelText:  'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: onObscureToggle,
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator:       AppValidators.passwordAdmin,
              onFieldSubmitted: (_) => onSubmit(),
            ),

            const SizedBox(height: 8),

            // Error message
            if (error != null)
              Container(
                margin:  const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color:      AppColors.errorDark,
                          fontSize:   13,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().shake(duration: 400.ms),

            const SizedBox(height: 28),

            // Sign In Button
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width:  22, height: 22,
                        child:  CircularProgressIndicator(
                          color:      Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                AppConstants.companyAddress,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize:   12,
                  color:      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}