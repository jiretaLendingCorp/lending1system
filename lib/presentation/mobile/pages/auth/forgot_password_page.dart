// lib/presentation/mobile/pages/auth/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.pop(),
                child: const Row(children: [
                  Icon(Icons.arrow_back_ios, size: 16),
                  Text('Back'),
                ]),
              ).animate().fadeIn(duration: 300.ms),

              const Spacer(),

              Center(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _sent
                          ? Container(
                              key: const ValueKey('sent'),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mark_email_read,
                                  size: 40, color: Colors.green),
                            )
                          : Container(
                              key: const ValueKey('notSent'),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lock_reset,
                                  size: 40,
                                  color: theme.colorScheme.primary),
                            ),
                    ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    Text(
                      _sent ? 'Check your email' : 'Forgot Password?',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                    const SizedBox(height: 10),

                    Text(
                      _sent
                          ? 'We\'ve sent a password reset link to\n${_emailCtrl.text.trim()}'
                          : 'Enter your registered email address and we\'ll send you a link to reset your password.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey, height: 1.5),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                    const SizedBox(height: 36),

                    if (!_sent) ...[
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon:
                                const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          validator: (v) => v!.contains('@')
                              ? null
                              : 'Enter a valid email',
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _send,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text('Send Reset Link',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to Login',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () => setState(() => _sent = false),
                        child: const Text('Resend email'),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    ],
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}