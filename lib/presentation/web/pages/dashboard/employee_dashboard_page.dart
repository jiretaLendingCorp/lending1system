// lib/presentation/web/pages/dashboard/employee_dashboard_page.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Employee Dashboard',
    icon: Icons.dashboard_rounded,
    description: 'Operational overview — loan applications, CI assignments, and collections.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/employees/employees_page.dart
class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Employee Management',
    icon: Icons.people_alt_rounded,
    description: 'Create, edit, suspend and manage employee accounts.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/riders/riders_page.dart
class RidersPage extends StatelessWidget {
  const RidersPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Rider Management',
    icon: Icons.delivery_dining_rounded,
    description: 'Manage field riders, monitor locations, and track performance.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/lenders/lenders_page.dart
class LendersPage extends StatelessWidget {
  const LendersPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Lender Management',
    icon: Icons.person_search_rounded,
    description: 'View borrower profiles, documents, and loan histories.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/collections/collections_page.dart
class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Collections Management',
    icon: Icons.payments_rounded,
    description: 'Assign and monitor payment collection operations.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/ci/ci_page.dart
class CiPage extends StatelessWidget {
  const CiPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Credit Investigation',
    icon: Icons.search_rounded,
    description: 'Manage CI assignments and review field reports.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/reports/reports_page.dart
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Reports & Analytics',
    icon: Icons.bar_chart_rounded,
    description: 'Generate and export financial, collection, and audit reports.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/settings/settings_page.dart
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'System Settings',
    icon: Icons.settings_rounded,
    description: 'Configure interest rates, fees, loan limits, and system parameters.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/web/pages/settings/audit_logs_page.dart
class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key});
  @override
  Widget build(BuildContext context) => _StubPage(
    title: 'Audit Logs',
    icon: Icons.history_rounded,
    description: 'Complete audit trail of all system actions and changes.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/dashboard/rider_dashboard_page.dart
class RiderDashboardPage extends StatelessWidget {
  const RiderDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Rider Dashboard',
    icon: Icons.delivery_dining_rounded,
    description: 'View your assignments, CI tasks, and collections.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/auth/register_page.dart
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Register Account',
    icon: Icons.person_add_rounded,
    description: 'Create your borrower account to apply for a loan.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/auth/forgot_password_page.dart
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Reset Password',
    icon: Icons.lock_reset_rounded,
    description: 'Enter your email to receive a password reset link.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/loans/loan_application_page.dart
class LoanApplicationPage extends StatelessWidget {
  const LoanApplicationPage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Apply for Loan',
    icon: Icons.add_card_rounded,
    description: 'Submit a new loan application from ₱5,000 to ₱500,000.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/loans/loan_detail_page.dart
class LoanDetailPage extends StatelessWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Loan Details',
    icon: Icons.account_balance_wallet_rounded,
    description: 'View payment schedule, balance, and loan information.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/payments/payment_page.dart
class PaymentPage extends StatelessWidget {
  final String loanId;
  const PaymentPage({super.key, required this.loanId});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Make Payment',
    icon: Icons.payment_rounded,
    description: 'Pay via GCash, Maya, QRPH, or card through PayMongo.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/ci/ci_report_page.dart
class CiReportPage extends StatelessWidget {
  final String assignmentId;
  const CiReportPage({super.key, required this.assignmentId});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'CI Report',
    icon: Icons.assignment_rounded,
    description: 'Submit credit investigation findings and photos.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/collections/collection_page.dart
class CollectionPage extends StatelessWidget {
  final String collectionId;
  const CollectionPage({super.key, required this.collectionId});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Collection',
    icon: Icons.receipt_rounded,
    description: 'Record payment collection and upload proof.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/profile/profile_page.dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'My Profile',
    icon: Icons.manage_accounts_rounded,
    description: 'Update your profile, photo, and personal information.',
  );
}

// ─────────────────────────────────────────────────────────────

// lib/presentation/mobile/pages/notifications/notifications_page.dart
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => _MobileStubPage(
    title: 'Notifications',
    icon: Icons.notifications_rounded,
    description: 'Payment reminders, loan updates, and system alerts.',
  );
}

// ─────────────────────────────────────────────────────────────
// Shared Stub Widgets
// ─────────────────────────────────────────────────────────────

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

class _MobileStubPage extends StatelessWidget {
  final String title, description;
  final IconData icon;
  const _MobileStubPage({required this.title, required this.icon, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color:        AppColors.primary50,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 64, color: AppColors.primary400),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              const _DevNote(),
            ],
          ),
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
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
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