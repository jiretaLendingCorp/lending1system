// lib/presentation/mobile/pages/auth/mobile_login_page.dart
// Jireta Loans & Credit Corp. 1996 — Mobile Login

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';

class MobileLoginPage extends ConsumerStatefulWidget {
  const MobileLoginPage({super.key});

  @override
  ConsumerState<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends ConsumerState<MobileLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool  _obscure   = true;
  bool  _loading   = false;
  String? _error;

  late AnimationController _bgCtrl;
  late Animation<double>    _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    final ok = await ref.read(authNotifierProvider.notifier).signInMobile(
      email:    _emailCtrl.text,
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      final role = ref.read(currentRoleProvider);
      if (role == 'rider') {
        context.go(AppConstants.routeRiderDashboard);
      } else {
        context.go(AppConstants.routeLenderDashboard);
      }
    } else {
      final err = ref.read(authNotifierProvider).error;
      setState(() => _error = err?.toString() ?? 'Login failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.lerp(
                    Alignment.bottomRight,
                    Alignment.bottomLeft,
                    _bgAnim.value,
                  )!,
                  colors: isDark
                      ? [AppColors.darkBackground, AppColors.primary900.withOpacity(0.6), AppColors.darkBackground]
                      : [AppColors.primary600, AppColors.primary500, AppColors.accent],
                ),
              ),
            ),
          ),

          // Decorative bubbles
          ..._buildBubbles(size, isDark),

          // Theme toggle
          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? AppColors.darkText : Colors.white,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.08),

                  // ── Logo ──────────────────────────────────
                  Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset:     const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.white, size: 42),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut)
                          .fadeIn(duration: 400.ms),

                      const SizedBox(height: 20),

                      const Text(
                        'Jireta Loans',
                        style: TextStyle(
                          fontFamily:  'Poppins',
                          fontSize:    28,
                          fontWeight:  FontWeight.w800,
                          color:       Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3),

                      const SizedBox(height: 6),

                      const Text(
                        '& Credit Corp. 1996',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize:   13,
                          color:      Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
                    ],
                  ),

                  SizedBox(height: size.height * 0.06),

                  // ── Login Card ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color:        isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                          blurRadius: 40,
                          offset:     const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize:   22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome back! Enter your credentials',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize:   13,
                              color:      Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Email
                          TextFormField(
                            controller:   _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect:  false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText:  'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: AppValidators.email,
                          ),

                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller:  _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText:  'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: AppValidators.password,
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go(AppConstants.routeForgotPassword),
                              child: const Text('Forgot password?',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),

                          // Error
                          if (_error != null)
                            Container(
                              margin:  const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:        AppColors.errorLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(fontFamily: 'Poppins', color: AppColors.errorDark, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ).animate().shake(duration: 400.ms),

                          const SizedBox(height: 8),

                          // Login button
                          SizedBox(
                            width:  double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Sign In',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 400.ms)
                   .fadeIn(duration: 500.ms)
                   .slideY(begin: 0.15, curve: Curves.easeOutCubic),

                  const SizedBox(height: 24),

                  // Register link (for lenders)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color:      isDark ? Colors.white70 : Colors.white,
                          fontSize:   14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppConstants.routeRegister),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontFamily:  'Poppins',
                            color:       Colors.white,
                            fontSize:    14,
                            fontWeight:  FontWeight.w700,
                            decoration:  TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBubbles(Size size, bool isDark) {
    final color = isDark
        ? AppColors.primary500.withOpacity(0.08)
        : Colors.white.withOpacity(0.1);

    return [
      Positioned(
        top: -60, right: -40,
        child: AnimatedBuilder(
          animation: _bgAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _bgAnim.value * 20),
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 120, left: -60,
        child: AnimatedBuilder(
          animation: _bgAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _bgAnim.value * -15),
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ),
      ),
      Positioned(
        top: size.height * 0.3, right: -30,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.5)),
        ),
      ),
    ];
  }
}