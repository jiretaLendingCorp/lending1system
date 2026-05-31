// lib/presentation/mobile/pages/profile/profile_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'code_history_page.dart';

final mobileProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authUid = Supabase.instance.client.auth.currentUser?.id;
  if (authUid == null) return {};
  final res = await Supabase.instance.client
      .from('users')
      .select('id, first_name, middle_name, last_name, email, phone_number, gender, civil_status, date_of_birth, account_status, profile_picture_url, last_login_at, role_id')
      .eq('auth_id', authUid)
      .maybeSingle();
  return res ?? {};
});

final mobileRoleProvider = FutureProvider<String>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return '';
  try {
    return await Supabase.instance.client.rpc('get_user_role').then((v) => (v as String?) ?? '');
  } catch (_) {
    return '';
  }
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _editMode = false;
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  bool _saving  = false;
  bool _loaded  = false;
  bool _uploadingPhoto = false;

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

      ref.invalidate(mobileProfileProvider);
      setState(() { _editMode = false; _loaded = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
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

  Future<void> _pickAndUploadPhoto() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Change Profile Photo', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take Photo', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: choice, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid == null) return;

      final bytes    = await picked.readAsBytes();
      final ext      = picked.path.split('.').last.toLowerCase();
      final fileName = 'avatar_$authUid.$ext';
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      await Supabase.instance.client.storage
          .from(AppConstants.bucketProfiles)
          .uploadBinary(
            fileName, bytes,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(AppConstants.bucketProfiles)
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('users')
          .update({'profile_picture_url': publicUrl})
          .eq('auth_id', authUid);

      ref.invalidate(mobileProfileProvider);
      ref.invalidate(authStateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go(AppConstants.routeMobileLogin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final async      = ref.watch(mobileProfileProvider);
    final roleAsync  = ref.watch(mobileRoleProvider);
    final role       = roleAsync.value ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          if (!_editMode)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _editMode = true),
              tooltip: 'Edit',
            )
          else
            TextButton(
              onPressed: () => setState(() { _editMode = false; _loaded = false; }),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          _loadProfile(p);
          final firstName = p['first_name']  as String? ?? '';
          final lastName  = p['last_name']   as String? ?? '';
          final email     = p['email']       as String? ?? '';
          final status    = p['account_status'] as String? ?? '';
          final avatarUrl = p['profile_picture_url'] as String?;
          final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            child: Column(children: [
              _AvatarSection(
                avatarUrl:       avatarUrl,
                initials:        initials,
                name:            '$firstName $lastName'.trim(),
                email:           email,
                role:            role,
                status:          status,
                uploadingPhoto:  _uploadingPhoto,
                onPhotoTap:      _pickAndUploadPhoto,
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              if (_editMode)
                _EditForm(
                  formKey:       _formKey,
                  firstNameCtrl: _firstNameCtrl,
                  lastNameCtrl:  _lastNameCtrl,
                  phoneCtrl:     _phoneCtrl,
                  saving:        _saving,
                  onSave:        _saveProfile,
                ).animate().fadeIn(duration: 300.ms)
              else
                _ProfileInfo(profile: p).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              _SettingsSection(onSignOut: _signOut),
            ]),
          );
        },
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final String?      avatarUrl;
  final String       initials, name, email, role, status;
  final bool         uploadingPhoto;
  final VoidCallback onPhotoTap;

  const _AvatarSection({
    required this.avatarUrl,
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.uploadingPhoto,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'active' ? AppColors.success
        : status == 'suspended' ? AppColors.error : AppColors.warning;

    return Column(children: [
      Stack(children: [
        GestureDetector(
          onTap: uploadingPhoto ? null : onPhotoTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: uploadingPhoto
                ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                : avatarUrl != null
                    ? ClipOval(child: Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))),
                      ))
                    : Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))),
          ),
        ),

        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: uploadingPhoto ? null : onPhotoTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
            ),
          ),
        ),

        Positioned(
          top: 2, right: 2,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text(name.isEmpty ? 'User' : name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(email, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
        child: Text(_roleLabel(role), style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    ]);
  }

  String _roleLabel(String r) =>
      {'rider': 'Rider', 'lender': 'Lender', 'employee': 'Employee', 'head_manager': 'Head Manager'}[r] ?? r;
}

class _ProfileInfo extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileInfo({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows   = [
      {'label': 'First Name',   'value': profile['first_name']   ?? '-'},
      {'label': 'Last Name',    'value': profile['last_name']    ?? '-'},
      {'label': 'Email',        'value': profile['email']        ?? '-'},
      {'label': 'Phone',        'value': profile['phone_number'] ?? '-'},
      {'label': 'Gender',       'value': profile['gender']       ?? '-'},
      {'label': 'Civil Status', 'value': profile['civil_status'] ?? '-'},
    ];

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final r = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: Text(r['label']!, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(r['value'] as String, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            if (e.key < rows.length - 1)
              Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ]);
        }).toList(),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  final GlobalKey<FormState>   formKey;
  final TextEditingController  firstNameCtrl, lastNameCtrl, phoneCtrl;
  final bool                   saving;
  final VoidCallback           onSave;

  const _EditForm({
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(children: [
        TextFormField(
          controller: firstNameCtrl,
          decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person_outline)),
          style: const TextStyle(fontFamily: 'Poppins'),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: lastNameCtrl,
          decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline)),
          style: const TextStyle(fontFamily: 'Poppins'),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller:   phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  final Future<void> Function() onSignOut;
  const _SettingsSection({required this.onSignOut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(children: [
        _SettingsTile(
          icon:  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: isDark ? 'Light Mode' : 'Dark Mode',
          onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        ),
        Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        _SettingsTile(
          icon:  Icons.history_rounded,
          label: 'Code History',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CodeHistoryPage())),
        ),
        Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        _SettingsTile(
          icon:  Icons.logout_rounded,
          label: 'Sign Out',
          color: AppColors.error,
          onTap: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title:   const Text('Sign Out', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
              content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Poppins')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
                ),
                ElevatedButton(
                  onPressed: () async { Navigator.pop(context); await onSignOut(); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color?       color;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading:  Icon(icon, color: c, size: 20),
          title:    Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: c)),
          trailing: Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}