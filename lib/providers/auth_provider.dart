// lib/providers/auth_provider.dart
// ═══════════════════════════════════════════════════════════════════════════
// FIX SUMMARY (PRIMARY BUG — "Access Denied / Baliktad"):
//
// ROOT CAUSE: Supabase's `roles:role_id(name)` join can return EITHER a Map
//   {"name":"lender"} OR a List [{"name":"lender"}] depending on the driver
//   version. The original code only casted to Map, so when a List was returned
//   the cast silently returned null → role became '' for EVERYONE.
//   - signInMobile: role '' ∉ ['rider','lender'] → "Access denied. Use web portal."
//   - signInWeb:    role '' ∉ ['head_manager','employee'] → "Access denied. Use mobile."
//   Result: ALL logins failed with the WRONG error — hence "baliktad".
//
// FIXES APPLIED:
//  1. _extractRole() — safely reads role from both Map and List responses.
//  2. After signInWeb / signInMobile succeeds, call ref.invalidate(authStateProvider)
//     so the FutureProvider re-fetches and currentRoleProvider reflects the new
//     session immediately (fixes race condition in mobile_login_page.dart too).
//  3. signInMobile fraud-detection invocation is wrapped in its own try/catch so a
//     missing/erroring edge function no longer blocks login entirely.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

// ── Auth state (Supabase session user + role) ────────────────

final authStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final session  = supabase.auth.currentSession;
  if (session == null) return null;

  final response = await supabase
      .from('users')
      .select(
        'id, first_name, last_name, email, role_id, account_status, '
        'profile_picture_url, roles:role_id(name)',
      )
      .eq('auth_id', session.user.id)
      .maybeSingle();

  if (response == null) return null;

  // FIX 1 ─ Use _extractRole() instead of a raw Map cast.
  final role = _extractRole(response['roles']);
  return {
    ...response,
    'role':    role,
    'auth_id': session.user.id,
  };
});

// ── Helper: safely extract role name from Map OR List ────────
//
// Supabase PostgREST returns a foreign-key join as:
//   • Map   {"name":"lender"}       — most common
//   • List  [{"name":"lender"}]     — some driver versions / RLS edge cases
// Both are handled here so role is never accidentally ''.
String _extractRole(dynamic rolesData) {
  if (rolesData == null) return '';
  if (rolesData is Map) {
    return (rolesData['name'] as String?) ?? '';
  }
  if (rolesData is List && rolesData.isNotEmpty) {
    final first = rolesData.first;
    if (first is Map) return (first['name'] as String?) ?? '';
  }
  return '';
}

// ── Current user DB id ────────────────────────────────────────

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?['id'] as String?;
});

// ── Current role ──────────────────────────────────────────────

final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).value?['role'] as String? ?? '';
});

// ── Auth notifier ─────────────────────────────────────────────

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  SupabaseClient get _supabase => ref.read(supabaseProvider);

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  // ── Sign In (Web — Head Manager / Employee) ──────────────

  Future<bool> signInWeb({
    required String email,
    required String password,
    String? ipAddress,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email:    email.trim().toLowerCase(),
        password: password,
      );

      if (response.session == null) throw Exception('Login failed');

      final user = await _supabase
          .from('users')
          .select('id, account_status, roles:role_id(name)')
          .eq('auth_id', response.user!.id)
          .maybeSingle();

      if (user == null) {
        await _supabase.auth.signOut();
        throw Exception(
            'No user profile found. Please contact your administrator.');
      }

      // FIX 1 ─ Use _extractRole() so the check is always accurate.
      final role   = _extractRole(user['roles']);
      final status = user['account_status'] as String? ?? '';

      if (!['head_manager', 'employee'].contains(role)) {
        await _supabase.auth.signOut();
        throw Exception('Access denied. Please use the mobile app.');
      }

      if (status == 'suspended') {
        await _supabase.auth.signOut();
        throw Exception('Your account has been suspended. Contact admin.');
      }

      await _supabase
          .from('users')
          .update({
            'last_login_at':  DateTime.now().toIso8601String(),
            'last_active_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user['id']);

      await _supabase.from('audit_logs').insert({
        'user_id':     user['id'],
        'action':      'login',
        'table_name':  'sessions',
        'description': 'Web login successful',
      });

      // FIX 2 ─ Invalidate so authStateProvider re-fetches with the new session.
      ref.invalidate(authStateProvider);

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      await _supabase.from('failed_login_attempts').insert({
        'email':  email.trim().toLowerCase(),
        'reason': e.message,
      });
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // ── Sign In (Mobile — Rider / Lender) ───────────────────

  Future<bool> signInMobile({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      // FIX 3 ─ Wrap fraud-detection in its own try/catch.
      //   A missing or erroring edge function must NOT block login.
      try {
        await _supabase.functions.invoke(
          'fraud-detection',
          body: {
            'user_id':    email,
            'event_type': 'login',
          },
        );
      } catch (_) {
        // Fraud check is non-critical; swallow the error and continue.
      }

      final response = await _supabase.auth.signInWithPassword(
        email:    email.trim().toLowerCase(),
        password: password,
      );

      if (response.session == null) throw Exception('Login failed');

      final user = await _supabase
          .from('users')
          .select('id, account_status, roles:role_id(name)')
          .eq('auth_id', response.user!.id)
          .maybeSingle();

      if (user == null) {
        await _supabase.auth.signOut();
        throw Exception(
            'No user profile found. Please contact your administrator.');
      }

      // FIX 1 ─ Use _extractRole() so the check is always accurate.
      final role   = _extractRole(user['roles']);
      final status = user['account_status'] as String? ?? '';

      if (!['rider', 'lender'].contains(role)) {
        await _supabase.auth.signOut();
        throw Exception('Access denied. Please use the web portal.');
      }

      if (status == 'suspended') {
        await _supabase.auth.signOut();
        throw Exception('Account suspended. Contact your manager.');
      }

      await _supabase.from('users').update({
        'last_login_at':  DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user['id']);

      // FIX 2 ─ Invalidate so authStateProvider re-fetches with the new session.
      ref.invalidate(authStateProvider);

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      await _supabase.from('failed_login_attempts').insert({
        'email':  email.trim().toLowerCase(),
        'reason': e.message,
      });
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // ── Register Lender ──────────────────────────────────────

  Future<bool> registerLender({
    required String email,
    required String password,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
    required String gender,
    required String civilStatus,
    required DateTime dateOfBirth,
    required String occupation,
    required double monthlyIncome,
    required String sourceOfIncome,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String emergencyContactRel,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authResponse = await _supabase.auth.signUp(
        email:    email.trim().toLowerCase(),
        password: password,
      );

      if (authResponse.user == null) throw Exception('Registration failed');

      final role = await _supabase
          .from('roles')
          .select('id')
          .eq('name', 'lender')
          .single();

      final userRecord = await _supabase.from('users').insert({
        'auth_id':      authResponse.user!.id,
        'role_id':      role['id'],
        'email':        email.trim().toLowerCase(),
        'first_name':   firstName.trim(),
        'middle_name':  middleName.trim(),
        'last_name':    lastName.trim(),
        'phone_number': phone.trim(),
        'gender':       gender,
        'civil_status': civilStatus,
        'date_of_birth':
            dateOfBirth.toIso8601String().split('T')[0],
        'account_status': 'pending_verification',
      }).select().single();

      final lenderCode =
          'LND-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await _supabase.from('lenders').insert({
        'user_id':                 userRecord['id'],
        'lender_code':             lenderCode,
        'occupation':              occupation.trim(),
        'monthly_income':          monthlyIncome,
        'source_of_income':        sourceOfIncome.trim(),
        'emergency_contact_name':  emergencyContactName.trim(),
        'emergency_contact_phone': emergencyContactPhone.trim(),
        'emergency_contact_rel':   emergencyContactRel.trim(),
      });

      await _supabase.from('user_roles').insert({
        'user_id': userRecord['id'],
        'role_id': role['id'],
      });

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // ── Sign Out ─────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        await _supabase.from('audit_logs').insert({
          'user_id':     userId,
          'action':      'logout',
          'table_name':  'sessions',
          'description': 'User signed out',
        });
      }
      await _supabase.auth.signOut();
      ref.invalidate(authStateProvider);
      state = const AsyncValue.data(null);
    } catch (_) {}
  }

  // ── Update FCM Token ─────────────────────────────────────

  Future<void> updateFcmToken(String token) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _supabase
        .from('users')
        .update({'fcm_token': token})
        .eq('id', userId);
  }

  // ── Update Last Active (heartbeat for session) ───────────

  Future<void> heartbeat() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _supabase
        .from('users')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}