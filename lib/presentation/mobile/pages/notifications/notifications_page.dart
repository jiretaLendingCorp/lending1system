// lib/presentation/mobile/pages/notifications/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', userId)
      .order('created_at', ascending: false)
      .limit(50)
      .map((rows) => List<Map<String, dynamic>>.from(rows));
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllRead(ref),
            child: const Text('Mark all read', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
        data: (notifs) => notifs.isEmpty
            ? _EmptyNotifications()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _NotificationTile(
                  notif: notifs[i],
                  onTap: () => _markRead(ref, notifs[i]['id'] as String),
                ).animate(delay: (40 * i).ms).fadeIn(duration: 300.ms),
              ),
      ),
    );
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  Future<void> _markRead(WidgetRef ref, String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onTap;
  const _NotificationTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isRead   = notif['is_read'] as bool? ?? false;
    final type     = notif['notification_type'] as String? ?? 'info';
    final title    = notif['title']   as String? ?? '';
    final body     = notif['body']    as String? ?? notif['message'] as String? ?? '';
    final created  = notif['created_at'] as String? ?? '';

    String dateLabel = '';
    if (created.isNotEmpty) {
      try {
        final dt = DateTime.parse(created);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          dateLabel = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          dateLabel = '${diff.inHours}h ago';
        } else {
          dateLabel = DateFormat('MMM d').format(dt);
        }
      } catch (_) {}
    }

    final typeColor = _typeColor(type);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:    onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        isRead
              ? (isDark ? AppColors.darkCard : Colors.white)
              : (isDark ? AppColors.primary900.withValues(alpha: 0.2) : AppColors.primary50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : AppColors.primary200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(type), color: typeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? _defaultTitle(type) : title,
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'loan_approved': return AppColors.success;
      case 'loan_rejected': return AppColors.error;
      case 'payment_due':   return AppColors.warning;
      case 'payment_received': return AppColors.success;
      case 'ci_assigned':   return AppColors.primary500;
      default:              return AppColors.info;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'loan_approved':    return Icons.check_circle_rounded;
      case 'loan_rejected':    return Icons.cancel_rounded;
      case 'payment_due':      return Icons.schedule_rounded;
      case 'payment_received': return Icons.payments_rounded;
      case 'ci_assigned':      return Icons.assignment_rounded;
      default:                 return Icons.notifications_rounded;
    }
  }

  String _defaultTitle(String t) {
    switch (t) {
      case 'loan_approved':    return 'Loan Approved';
      case 'loan_rejected':    return 'Loan Rejected';
      case 'payment_due':      return 'Payment Due';
      case 'payment_received': return 'Payment Received';
      case 'ci_assigned':      return 'New CI Assignment';
      default:                 return 'Notification';
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:        AppColors.primary50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.primary400),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          const Text('No notifications yet', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600))
              .animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 6),
          Text("You're all caught up!", style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))
              .animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }
}