// lib/presentation/mobile/pages/profile/code_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';

class CodeHistoryPage extends StatelessWidget {
  const CodeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Code History', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _changelog.length,
        itemBuilder: (context, i) {
          final entry = _changelog[i];
          return _ChangelogCard(entry: entry, isLatest: i == 0)
              .animate(delay: Duration(milliseconds: i * 60))
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.05, end: 0);
        },
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final _ChangelogEntry entry;
  final bool            isLatest;
  const _ChangelogCard({required this.entry, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.primary300 : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isLatest ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLatest ? AppColors.primary500 : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.version,
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700,
                  color: isLatest ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText),
                ),
              ),
            ),
            if (isLatest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight, borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Latest', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.successDark)),
              ),
            ],
            const Spacer(),
            Text(entry.date, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          ...entry.changes.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 6, height: 6,
                decoration: BoxDecoration(color: _typeColor(c.type), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(c.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(c.type.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: _typeColor(c.type))),
                  ),
                  const SizedBox(height: 2),
                  Text(c.description, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                ]),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fix':     return AppColors.success;
      case 'feat':    return AppColors.primary500;
      case 'change':  return AppColors.warning;
      case 'remove':  return AppColors.error;
      default:        return AppColors.info;
    }
  }
}

class _ChangelogEntry {
  final String version, date;
  final List<_ChangelogChange> changes;
  const _ChangelogEntry({required this.version, required this.date, required this.changes});
}

class _ChangelogChange {
  final String type, description;
  const _ChangelogChange(this.type, this.description);
}

const _changelog = [
  _ChangelogEntry(
    version: 'v1.5.0',
    date: 'May 31, 2026',
    changes: [
      _ChangelogChange('fix',    'Interest rate locked to 10% — lender can no longer change it'),
      _ChangelogChange('fix',    'Loan submit now uses correct DB schema (loan_code, lender_id from lenders table, principal_amount, payment_frequency)'),
      _ChangelogChange('feat',   'Profile picture change: pick from camera or gallery and upload to storage'),
      _ChangelogChange('remove', 'Removed "Your Capabilities" section from profile page'),
      _ChangelogChange('feat',   'Code History page added'),
      _ChangelogChange('fix',    'Sign out now correctly redirects to login on both mobile and web'),
      _ChangelogChange('fix',    'Mobile nav bar taps now reliable — HitTestBehavior.opaque applied'),
      _ChangelogChange('fix',    'Web sidebar items are now all clickable — transparent hit-test fixed'),
      _ChangelogChange('fix',    'Login role check uses SECURITY DEFINER RPC (get_user_role) — no more Access Denied'),
      _ChangelogChange('change', 'Default interest rate updated to 10% across all new loan applications'),
    ],
  ),
  _ChangelogEntry(
    version: 'v1.4.0',
    date: 'May 20, 2026',
    changes: [
      _ChangelogChange('feat', 'Lender loan application multi-step form'),
      _ChangelogChange('feat', 'Rider assignment and collection pages'),
      _ChangelogChange('feat', 'Credit investigation (CI) report page'),
      _ChangelogChange('fix',  'Bottom nav selected index now derived from router state, not local state'),
    ],
  ),
  _ChangelogEntry(
    version: 'v1.3.0',
    date: 'May 10, 2026',
    changes: [
      _ChangelogChange('feat', 'Floating bottom nav bar for mobile with press animation'),
      _ChangelogChange('feat', 'Dark/light mode toggle in profile settings'),
      _ChangelogChange('feat', 'Lender dashboard with active loan summaries'),
      _ChangelogChange('feat', 'Notification bell with unread count badge'),
    ],
  ),
  _ChangelogEntry(
    version: 'v1.2.0',
    date: 'Apr 28, 2026',
    changes: [
      _ChangelogChange('feat', 'Web admin dashboard with charts'),
      _ChangelogChange('feat', 'Employee and rider management pages'),
      _ChangelogChange('feat', 'Audit log viewer for head manager'),
      _ChangelogChange('fix',  'Web sidebar auto-collapses on screen width < 1100px'),
    ],
  ),
  _ChangelogEntry(
    version: 'v1.1.0',
    date: 'Apr 14, 2026',
    changes: [
      _ChangelogChange('feat', 'Role-based routing: web for admin/employee, mobile for rider/lender'),
      _ChangelogChange('feat', 'Supabase Auth integration with role lookup via RPC'),
      _ChangelogChange('feat', 'Lender registration multi-step form'),
      _ChangelogChange('feat', 'Forgot password flow'),
    ],
  ),
  _ChangelogEntry(
    version: 'v1.0.0',
    date: 'Apr 1, 2026',
    changes: [
      _ChangelogChange('feat', 'Initial release — Jireta Loans & Credit Corp. 1996 system'),
      _ChangelogChange('feat', 'Flutter project setup with GoRouter and Riverpod'),
      _ChangelogChange('feat', 'Supabase database schema with full RLS policies'),
      _ChangelogChange('feat', 'Poppins font, app colors, theme system'),
    ],
  ),
];