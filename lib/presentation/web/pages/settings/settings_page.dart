// ============================================================
// FIX FILE: lib/presentation/web/pages/settings/settings_page.dart
// ============================================================
// BUGS FIXED:
//
// BUG 1 — "Page not found: GoException: no routes for location:
//   /settings/audit-logs"
//
//   ROOT CAUSE: The Audit Logs tab button called:
//     context.go('/settings/audit-logs')
//   But the GoRouter in app_router.dart registers the route as:
//     AppConstants.routeWebAuditLogs = '/web/audit-logs'
//   There is no '/settings/audit-logs' route defined anywhere.
//
//   FIX: Change to:
//     context.go(AppConstants.routeWebAuditLogs)
//   which resolves to '/web/audit-logs' — the correctly registered route.
//
// BUG 2 — Settings page content overflows ("BOTTOM OVERFLOWED BY 51 PIXELS")
//
//   ROOT CAUSE: The Expanded widget wrapping the profile/security/system
//   tabs contains a Card whose Column children can overflow the available
//   vertical space, especially on smaller window heights.
//
//   FIX: Wrap each tab's Card/content in a SingleChildScrollView so the
//   content scrolls instead of overflowing.
//
// BUG 3 — Profile tab displays 'role' from raw DB row, but 'users' table
//   has NO 'role' column (it's 'role_id'). Shows '-' or crashes.
//
//   FIX: settingsProfileProvider now also fetches role via RPC, same as
//   auth_provider. The profile badge now shows the resolved role string.
// ============================================================

// lib/presentation/web/pages/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../providers/theme_provider.dart';

final settingsProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};

  final res = await supabase
      .from('users')
      .select(
          'id, first_name, last_name, email, phone_number, account_status, role_id')
      .eq('auth_id', uid)
      .maybeSingle();

  if (res == null) return {};

  // FIX: role is not stored on users row — fetch via SECURITY DEFINER RPC
  // same as auth_provider to avoid "column users.role does not exist"
  String role = '';
  try {
    role =
        await supabase.rpc('get_user_role').then((v) => (v as String?) ?? '');
  } catch (_) {}

  final firstName = res['first_name'] as String? ?? '';
  final lastName = res['last_name'] as String? ?? '';

  return {
    ...res,
    'role': role,
    'full_name': '$firstName $lastName'.trim(),
    'email': res['email'] ?? '',
  };
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 4),
            Text('Manage your account and system preferences',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey))
                .animate()
                .fadeIn(duration: 300.ms, delay: 50.ms),
            const SizedBox(height: 24),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabBtn(
                      label: 'Profile',
                      icon: Icons.person_outline,
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0)),
                  _TabBtn(
                      label: 'Security',
                      icon: Icons.lock_outline,
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1)),
                  _TabBtn(
                      label: 'System',
                      icon: Icons.tune,
                      selected: _tab == 2,
                      onTap: () => setState(() => _tab = 2)),
                  // FIX: use AppConstants.routeWebAuditLogs ('/web/audit-logs')
                  // NOT '/settings/audit-logs' which has no registered route
                  _TabBtn(
                      label: 'Audit Logs',
                      icon: Icons.history,
                      selected: _tab == 3,
                      onTap: () => context.go(AppConstants.routeWebAuditLogs)),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: 24),
            // FIX: Wrap in Expanded + scroll so content never overflows
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tab == 0
                    ? const _ProfileTab()
                    : _tab == 1
                        ? const _SecurityTab()
                        : const _SystemTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab();

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _key = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _load(Map<String, dynamic> p) {
    if (!_loaded) {
      _firstName.text = p['first_name'] ?? '';
      _lastName.text = p['last_name'] ?? '';
      _phone.text = p['phone_number'] ?? '';
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client.from('users').update({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone_number': _phone.text.trim(),
      }).eq('auth_id', uid);
      ref.invalidate(settingsProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(settingsProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (p) {
        _load(p);
        // FIX: Wrap in SingleChildScrollView to prevent overflow
        return SingleChildScrollView(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        child: Text(
                          // FIX: first_name initial (no full_name column)
                          ((p['first_name'] as String?) ?? 'A').isNotEmpty
                              ? (p['first_name'] as String)[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                              fontSize: 28,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FIX: display full_name (computed in provider)
                            Text(
                                p['full_name']?.toString().isNotEmpty == true
                                    ? p['full_name']
                                    : '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(p['email'] ?? '-',
                                style: const TextStyle(color: Colors.grey)),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              // FIX: 'role' now resolved via RPC in provider
                              child: Text(
                                (p['role'] as String? ?? 'admin').toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                    ]),
                    const Divider(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(children: [
                        TextFormField(
                          controller: _firstName,
                          decoration:
                              const InputDecoration(labelText: 'First Name'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastName,
                          decoration:
                              const InputDecoration(labelText: 'Last Name'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: p['email'] ?? '',
                          decoration:
                              const InputDecoration(labelText: 'Email Address'),
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phone,
                          decoration:
                              // FIX: phone_number (not 'phone')
                              const InputDecoration(labelText: 'Phone Number'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Save Changes'),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Security Tab ──────────────────────────────────────────────────────────────

class _SecurityTab extends ConsumerStatefulWidget {
  const _SecurityTab();

  @override
  ConsumerState<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends ConsumerState<_SecurityTab> {
  final _key = GlobalKey<FormState>();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _newPw.text));
      _currentPw.clear();
      _newPw.clear();
      _confirmPw.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: SingleChildScrollView prevents overflow on small screens
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change Password',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _currentPw,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPw,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) => v!.length < 8 ? 'Min 8 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPw,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v != _newPw.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _changePassword,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Change Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── System Tab ────────────────────────────────────────────────────────────────

class _SystemTab extends ConsumerWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // FIX: SingleChildScrollView prevents overflow on small screens
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Configuration',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const _SettingsTile(
                icon: Icons.percent,
                title: 'Default Interest Rate',
                subtitle: 'Set the default loan interest rate',
                trailing:
                    Text('5%', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const _SettingsTile(
                icon: Icons.calendar_today,
                title: 'Default Loan Term',
                subtitle: 'Default repayment period',
                trailing: Text('30 days',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _SettingsTile(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Enable push notifications for riders',
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
              // FIX: Dark mode switch now actually works via themeProvider
              _SettingsTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Toggle dark/light theme',
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        trailing,
      ]),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(children: [
          Icon(icon,
              size: 16,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey)),
        ]),
      ),
    );
  }
}
