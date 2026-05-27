// lib/presentation/mobile/pages/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        data: {
          'full_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'role': 'lender',
        },
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Registration Successful'),
            content: const Text(
                'Please check your email to verify your account before logging in.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Back button
              GestureDetector(
                onTap: () => context.pop(),
                child: const Row(children: [
                  Icon(Icons.arrow_back_ios, size: 16),
                  Text('Back'),
                ]),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 32),

              // Logo area
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.account_balance,
                    color: theme.colorScheme.primary, size: 28),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 20),

              Text('Create Account',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideX(begin: -0.1),

              const SizedBox(height: 6),

              Text('Register as a lender to get started',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey))
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms),

              const SizedBox(height: 32),

              // Form
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec(
                        label: 'Full Name',
                        icon: Icons.person_outline),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Full name is required' : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec(
                        label: 'Email Address',
                        icon: Icons.email_outlined),
                    validator: (v) =>
                        v!.contains('@') ? null : 'Enter a valid email',
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec(
                        label: 'Phone Number',
                        icon: Icons.phone_outlined),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePw,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec(
                      label: 'Password',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePw
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscurePw = !_obscurePw),
                      ),
                    ),
                    validator: (v) => v!.length >= 8
                        ? null
                        : 'Password must be at least 8 characters',
                  ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: _inputDec(
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => v != _passwordCtrl.text
                        ? 'Passwords do not match'
                        : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 450.ms),

                  const SizedBox(height: 20),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text('Sign In',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]).animate().fadeIn(duration: 400.ms, delay: 500.ms),

                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(
          {required String label, required IconData icon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      );
}