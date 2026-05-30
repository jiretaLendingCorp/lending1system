// lib/presentation/web/pages/dashboard/employee_dashboard_page.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIX: Removed all stub page classes that were duplicating classes already
// defined in their own dedicated files. Having them here caused:
//   - ambiguous_import errors in app_router.dart (~14 errors)
//   - invocation_of_non_function errors (CiReportPage, CollectionPage,
//     LoanDetailPage, PaymentPage — compiler resolved the ambiguous name to
//     the non-widget version)
//
// Kept only: EmployeeDashboardPage, _StubPage, _DevNote
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => const _StubPage(
    title: 'Employee Dashboard',
    icon: Icons.dashboard_rounded,
    description: 'Operational overview — loan applications, CI assignments, and collections.',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Stub Widget (used only by EmployeeDashboardPage above)
// ─────────────────────────────────────────────────────────────────────────────

class _StubPage extends StatelessWidget {
  final String title, description;
  final IconData icon;
  const _StubPage({required this.title, required this.icon, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color:        AppColors.primary50,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(icon, size: 80, color: AppColors.primary400),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 400,
                    child: Text(description, textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 20),
                  const _DevNote(),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DevNote extends StatelessWidget {
  const _DevNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        AppColors.infoLight,
        borderRadius: BorderRadius.circular(20),
        // FIX: withOpacity → withValues(alpha:) — deprecated after Flutter 3.x
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
          SizedBox(width: 8),
          Text('Implementation ready — wire to Supabase', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.infoDark, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}