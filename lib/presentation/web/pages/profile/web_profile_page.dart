// lib/presentation/web/pages/profile/web_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

final webProfileDetailProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return {};
  final res = await Supabase.instance.client
      .from('users')
      .select('id, first_name, middle_name, last_name, email, phone_number, '
              'gender, civil_status, date_of_birth, account_status, '
              'profile_picture_url, last_login_at, last_active_at, created_at')
      .eq('auth_id', authUid)
      .maybeSingle();
  return res ?? {};
});

class WebProfilePage extends ConsumerStatefulWidget {
  const WebProfilePage({super.key});
  @override ConsumerState<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends ConsumerState<WebProfilePage> {
  bool    _editMode = false;
  final   _formKey  = GlobalKey<FormState>();
  final   _firstNameCtrl = TextEditingController();
  final   _lastNameCtrl  = TextEditingController();
  final   _phoneCtrl     = TextEditingController();
  bool    _saving  = false;
  bool    _loaded  = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _loadProfile(Map<String, dynamic> p) {
    if (!_loaded) {
      _firstNameCtrl.text = p['first_name']   as String? ?? '';
      _lastNameCtrl.text  = p['last_name']    as String? ?? '';
      _phoneCtrl.text     = p['phone_number'] as String? ?? '';
      _loaded = true;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid == null) return;
      await Supabase.instance.client.from('users').update({
        'first_name':   _firstNameCtrl.text.trim(),
        'last_name':    _lastNameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      }).eq('auth_id', authUid);
      ref.invalidate(webProfileDetailProvider);
      setState(() { _editMode = false; _loaded = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async      = ref.watch(webProfileDetailProvider);
    final authUser   = ref.watch(authStateProvider).value;
    final role       = authUser?['role'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          _loadProfile(p);
          final firstName = p['first_name']  as String? ?? '';
          final lastName  = p['last_name']   as String? ?? '';
          final email     = p['email']       as String? ?? '';
          final avatarUrl = p['profile_picture_url'] as String?;
          final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
                    if (!_editMode)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _editMode = true),
                        icon:  const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit Profile', style: TextStyle(fontFamily: 'Poppins')),
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() { _editMode = false; _loaded = false; }),
                            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            child: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save Changes', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                          ),
                        ],
                      ),
                  ],
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: _AvatarCard(
                        avatarUrl: avatarUrl,
                        initials:  initials,
                        name:      '$firstName $lastName'.trim(),
                        email:     email,
                        role:      role,
                        status:    p['account_status'] as String? ?? '',
                      ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          if (_editMode)
                            _EditCard(
                              formKey:       _formKey,
                              firstNameCtrl: _firstNameCtrl,
                              lastNameCtrl:  _lastNameCtrl,
                              phoneCtrl:     _phoneCtrl,
                            ).animate().fadeIn(duration: 300.ms)
                          else
                            _InfoCard(profile: p).animate(delay: 150.ms).fadeIn(duration: 400.ms),

                          const SizedBox(height: 20),

                          _RoleCapabilitiesCard(role: role).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final String? avatarUrl;
  final String  initials, name, email, role, status;
  const _AvatarCard({required this.avatarUrl, required this.initials, required this.name, required this.email, required this.role, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final statusColor = status == 'active' ? AppColors.success
        : status == 'suspended' ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape:   BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: avatarUrl != null
                ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)))))
                : Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(height: 16),
          Text(name.isEmpty ? 'User' : name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Text(_roleLabel(role), style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String r) => {'rider': 'Rider', 'lender': 'Lender', 'employee': 'Employee', 'head_manager': 'Head Manager'}[r] ?? r;
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _InfoCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows   = [
      _Row('First Name',   profile['first_name']   ?? '-'),
      _Row('Last Name',    profile['last_name']    ?? '-'),
      _Row('Email',        profile['email']        ?? '-'),
      _Row('Phone',        profile['phone_number'] ?? '-'),
      _Row('Gender',       profile['gender']       ?? '-'),
      _Row('Civil Status', profile['civil_status'] ?? '-'),
    ];

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Personal Information', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ...rows.map((r) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(width: 130, child: Text(r.label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    Expanded(child: Text(r.value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ],
          )),
        ],
      ),
    );
  }
}

class _Row { final String label, value; const _Row(this.label, this.value); }

class _EditCard extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController firstNameCtrl, lastNameCtrl, phoneCtrl;
  const _EditCard({required this.formKey, required this.firstNameCtrl, required this.lastNameCtrl, required this.phoneCtrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller:  phoneCtrl,
              keyboardType:TextInputType.phone,
              decoration:  const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCapabilitiesCard extends StatelessWidget {
  final String role;
  const _RoleCapabilitiesCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final caps   = _getCaps(role);
    if (caps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Access & Capabilities', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: caps.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.primary50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c['icon'] as IconData, size: 16, color: AppColors.primary600),
                  const SizedBox(width: 8),
                  Text(c['label'] as String, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary700)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getCaps(String role) {
    switch (role) {
      case 'head_manager': return [
          {'icon': Icons.dashboard_rounded,   'label': 'Full Dashboard'},
          {'icon': Icons.people_alt_rounded,  'label': 'Manage Employees'},
          {'icon': Icons.delivery_dining,     'label': 'Manage Riders'},
          {'icon': Icons.person_search,       'label': 'Manage Lenders'},
          {'icon': Icons.account_balance_wallet,'label': 'Manage Loans'},
          {'icon': Icons.payments_rounded,    'label': 'Collections'},
          {'icon': Icons.search_rounded,      'label': 'Credit Investigation'},
          {'icon': Icons.bar_chart_rounded,   'label': 'Reports'},
          {'icon': Icons.history_rounded,     'label': 'Audit Logs'},
          {'icon': Icons.settings_rounded,    'label': 'System Settings'},
        ];
      case 'employee': return [
          {'icon': Icons.dashboard_rounded,     'label': 'Operations Dashboard'},
          {'icon': Icons.delivery_dining,       'label': 'View Riders'},
          {'icon': Icons.person_search,         'label': 'View Lenders'},
          {'icon': Icons.account_balance_wallet,'label': 'Process Loans'},
          {'icon': Icons.payments_rounded,      'label': 'Collections'},
          {'icon': Icons.search_rounded,        'label': 'Credit Investigation'},
          {'icon': Icons.bar_chart_rounded,     'label': 'View Reports'},
        ];
      default: return [];
    }
  }
}