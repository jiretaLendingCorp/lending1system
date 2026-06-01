// lib/providers/auth_provider.dart
// ═══════════════════════════════════════════════════════════════════════════
// DEFINITIVE FIX — "Access Denied" for lender/rider on mobile login
//
// ROOT CAUSE (confirmed from schema.sql):
//   The query used `roles:role_id(name)` — a PostgREST embedded join. For
//   PostgREST to follow a FK join, the `authenticated` Postgres role needs
//   GRANT SELECT on the `roles` table. The schema.sql never grants this, so
//   the join silently returns null → role = '' → every login gets denied.
//
//   This is why:
//     mobile login: role '' ∉ ['rider','lender']   → "Access denied. Use web portal."
//     web login:    role '' ∉ ['head_manager','employee'] → "Access denied. Use mobile."
//
// THE REAL FIX (replaces the join entirely):
//   Call the `get_user_role()` Postgres RPC that already exists in schema.sql.
//   It is declared SECURITY DEFINER, so it runs as the Postgres superuser and
//   ALWAYS has permission to read both `users` and `roles` — no GRANT needed.
//
//     await _supabase.rpc('get_user_role')
//
//   This one change makes the login work for all four roles.
//
// ADDITIONAL FIXES IN THIS FILE:
//   • fraud-detection edge function wrapped in try/catch (non-critical check)
//   • ref.invalidate(authStateProvider) called after login so the riverpod
//     cache re-fetches with the new session (prevents stale role reads)
//   • authStateProvider also uses get_user_role() RPC — same reason
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider =
    Provider<SupabaseClient>((_) => Supabase.instance.client);

// ── Auth state (Supabase session user + role) ────────────────

final authStateProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final session = supabase.auth.currentSession;
  if (session == null) return null;

  // Step 1: fetch basic user profile
  final response = await supabase
      .from('users')
      .select(
        'id, first_name, last_name, email, role_id, '
        'account_status, profile_picture_url',
      )
      .eq('auth_id', session.user.id)
      .maybeSingle();

  if (response == null) return null;

  // Step 2: get role via SECURITY DEFINER RPC — always works, no GRANT needed
  final role =
      await supabase.rpc('get_user_role').then((v) => (v as String?) ?? '');

  return {
    ...response,
    'role':    role,
    'auth_id': session.user.id,
  };
});

// ── Current user DB id ────────────────────────────────────────

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?['id'] as String?;
});

// ── Current role ──────────────────────────────────────────────

final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).value?['role'] as String? ?? '';
});

// ── Auth notifier ─────────────────────────────────────────────

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  SupabaseClient get _supabase => ref.read(supabaseProvider);

  // Riverpod 2.x: Notifier<T> requires a synchronous build() that returns
  // the initial state. AsyncValue.data(null) means "idle / no operation".
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

      // ── Get role via SECURITY DEFINER RPC ──────────────
      final role = await _supabase
          .rpc('get_user_role')
          .then((v) => (v as String?) ?? '');

      if (!['head_manager', 'employee'].contains(role)) {
        await _supabase.auth.signOut();
        throw Exception('Access denied. Please use the mobile app.');
      }

      // ── Fetch user row for status / id ─────────────────
      final user = await _supabase
          .from('users')
          .select('id, account_status')
          .eq('auth_id', response.user!.id)
          .maybeSingle();

      if (user == null) {
        await _supabase.auth.signOut();
        throw Exception(
            'No user profile found. Please contact your administrator.');
      }

      final status = user['account_status'] as String? ?? '';
      if (status == 'suspended') {
        await _supabase.auth.signOut();
        throw Exception('Your account has been suspended. Contact admin.');
      }

      await _supabase.from('users').update({
        'last_login_at':  DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user['id']);

      await _supabase.from('audit_logs').insert({
        'user_id':     user['id'],
        'action':      'login',
        'table_name':  'sessions',
        'description': 'Web login successful',
      });

      // Re-fetch auth state with new session
      ref.invalidate(authStateProvider);

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      try {
        await _supabase.from('failed_login_attempts').insert({
          'email':  email.trim().toLowerCase(),
          'reason': e.message,
        });
      } catch (_) {}
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
      // Fraud check is non-critical — swallow any error and continue
      try {
        await _supabase.functions.invoke(
          'fraud-detection',
          body: {'user_id': email, 'event_type': 'login'},
        );
      } catch (_) {}

      final response = await _supabase.auth.signInWithPassword(
        email:    email.trim().toLowerCase(),
        password: password,
      );

      if (response.session == null) throw Exception('Login failed');

      // ── Get role via SECURITY DEFINER RPC ──────────────
      final role = await _supabase
          .rpc('get_user_role')
          .then((v) => (v as String?) ?? '');

      if (!['rider', 'lender'].contains(role)) {
        await _supabase.auth.signOut();
        throw Exception('Access denied. Please use the web portal.');
      }

      // ── Fetch user row for status / id ─────────────────
      final user = await _supabase
          .from('users')
          .select('id, account_status')
          .eq('auth_id', response.user!.id)
          .maybeSingle();

      if (user == null) {
        await _supabase.auth.signOut();
        throw Exception(
            'No user profile found. Please contact your administrator.');
      }

      final status = user['account_status'] as String? ?? '';
      if (status == 'suspended') {
        await _supabase.auth.signOut();
        throw Exception('Account suspended. Contact your manager.');
      }

      await _supabase.from('users').update({
        'last_login_at':  DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user['id']);

      // Re-fetch auth state with new session
      ref.invalidate(authStateProvider);

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      try {
        await _supabase.from('failed_login_attempts').insert({
          'email':  email.trim().toLowerCase(),
          'reason': e.message,
        });
      } catch (_) {}
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
        'auth_id':       authResponse.user!.id,
        'role_id':       role['id'],
        'email':         email.trim().toLowerCase(),
        'first_name':    firstName.trim(),
        'middle_name':   middleName.trim(),
        'last_name':     lastName.trim(),
        'phone_number':  phone.trim(),
        'gender':        gender,
        'civil_status':  civilStatus,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
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
    // Step 1: audit log (non-critical — never block sign-out if this fails)
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
    } catch (_) {}

    // Step 2: always sign out — separate catch so audit failure cannot block this
    try {
      await _supabase.auth.signOut();
    } catch (_) {}

    // Step 3: clear Riverpod state
    try {
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

  // ── Heartbeat ────────────────────────────────────────────

  Future<void> heartbeat() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _supabase
        .from('users')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }
}