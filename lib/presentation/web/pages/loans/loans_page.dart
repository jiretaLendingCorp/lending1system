// lib/presentation/web/pages/loans/loans_page.dart
// Jireta Loans & Credit Corp. 1996 — Loans Management Web Page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../widgets/modals/loan_detail_modal.dart';
import '../widgets/modals/approve_loan_modal.dart';
import '../widgets/modals/assign_ci_modal.dart';
import '../widgets/web_data_table.dart';
import '../widgets/status_badge.dart';

// ── Providers ────────────────────────────────────────────────

final loansFilterProvider = StateProvider<String>((ref) => 'all');
final loansSearchProvider = StateProvider<String>((ref) => '');
final loansPageProvider   = StateProvider<int>((ref) => 0);

final loansListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(loansFilterProvider);
  final search = ref.watch(loansSearchProvider);
  final page   = ref.watch(loansPageProvider);

  var query = Supabase.instance.client
      .from('loans')
      .select('''
        id, loan_code, principal_amount, total_payable, outstanding_balance,
        loan_status, payment_frequency, payment_amount, term_days,
        interest_rate, created_at, disbursed_at,
        lenders:lender_id (
          lender_code,
          users:user_id ( first_name, last_name, email, phone_number )
        )
      ''')
      .eq('is_archived', false);

  if (filter != 'all') {
    query = query.eq('loan_status', filter) as dynamic;
  }

  final from = page * 20;
  final to   = from + 19;

  return await (query as dynamic)
      .order('created_at', ascending: false)
      .range(from, to);
});

// ─────────────────────────────────────────────────────────────
// Loans Page
// ─────────────────────────────────────────────────────────────

class LoansPage extends ConsumerWidget {
  const LoansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(loansFilterProvider);
    final loans  = ref.watch(loansListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loan Management',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
                    Text(
                      'Manage and monitor all loan applications',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 20),

            // ── Status Filter Chips ───────────────────────────
            _StatusFilterRow(
              current:  filter,
              onSelect: (s) => ref.read(loansFilterProvider.notifier).state = s,
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 16),

            // ── Search bar ────────────────────────────────────
            _SearchBar(
              onChanged: (v) {
                ref.read(loansSearchProvider.notifier).state = v;
                ref.read(loansPageProvider.notifier).state   = 0;
              },
            ).animate(delay: 150.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 16),

            // ── Data Table ────────────────────────────────────
            Expanded(
              child: loans.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (e, __) => Center(child: Text('Error: $e')),
                data:    (data) => _LoansTable(
                  loans: data,
                  onRefresh: () => ref.refresh(loansListProvider),
                ),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

            // ── Pagination ────────────────────────────────────
            _PaginationRow(
              page:     ref.watch(loansPageProvider),
              hasMore:  (loans.value?.length ?? 0) >= 20,
              onPrev:   () {
                final p = ref.read(loansPageProvider);
                if (p > 0) ref.read(loansPageProvider.notifier).state = p - 1;
              },
              onNext: () {
                ref.read(loansPageProvider.notifier).state++;
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Filter Row
// ─────────────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;

  const _StatusFilterRow({required this.current, required this.onSelect});

  static const filters = [
    ('all',       'All'),
    ('pending',   'Pending'),
    ('under_ci',  'Under CI'),
    ('approved',  'Approved'),
    ('active',    'Active'),
    ('overdue',   'Overdue'),
    ('completed', 'Completed'),
    ('rejected',  'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = current == f.$1;
          final color    = f.$1 == 'all'
              ? AppColors.primary500
              : AppColors.loanStatusColor(f.$1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                label: Text(
                  f.$2,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize:   12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color:      selected ? Colors.white : color,
                  ),
                ),
                selected:       selected,
                onSelected:     (_) => onSelect(f.$1),
                backgroundColor: color.withOpacity(0.08),
                selectedColor:   color,
                checkmarkColor:  Colors.white,
                side: BorderSide(color: color.withOpacity(selected ? 0 : 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final void Function(String) onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText:    'Search by loan code, borrower name, email…',
          hintStyle:   TextStyle(fontFamily: 'Poppins', fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon:  const Icon(Icons.search_rounded, size: 20),
          filled:      true,
          fillColor:   Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loans Table
// ─────────────────────────────────────────────────────────────

class _LoansTable extends StatelessWidget {
  final List<Map<String, dynamic>> loans;
  final VoidCallback onRefresh;
  const _LoansTable({required this.loans, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No loans found', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Try adjusting your filters', style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight:  48,
            dataRowMinHeight:  56,
            dataRowMaxHeight:  64,
            columnSpacing:     24,
            horizontalMargin:  20,
            headingTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize:   12,
              color:      Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            columns: const [
              DataColumn(label: Text('LOAN CODE')),
              DataColumn(label: Text('BORROWER')),
              DataColumn(label: Text('PRINCIPAL'), numeric: true),
              DataColumn(label: Text('BALANCE'),   numeric: true),
              DataColumn(label: Text('PAYMENT')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: loans.asMap().entries.map((entry) {
              final i    = entry.key;
              final loan = entry.value;

              final lender   = loan['lenders'] as Map? ?? {};
              final user     = lender['users'] as Map? ?? {};
              final firstName= user['first_name'] as String? ?? '';
              final lastName = user['last_name']  as String? ?? '';
              final code     = loan['loan_code'] as String? ?? '';
              final status   = loan['loan_status'] as String? ?? '';
              final principal= (loan['principal_amount'] as num?)?.toDouble() ?? 0;
              final balance  = (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
              final payAmt   = (loan['payment_amount'] as num?)?.toDouble() ?? 0;
              final freq     = loan['payment_frequency'] as String? ?? '';

              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (i.isOdd) {
                    return isDark
                        ? AppColors.darkSurfaceVariant.withOpacity(0.3)
                        : AppColors.lightSurfaceVariant;
                  }
                  return null;
                }),
                cells: [
                  DataCell(
                    Text(code, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary500)),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text('$firstName $lastName',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(user['email'] as String? ?? '',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  DataCell(
                    Text('₱${_fmt(principal)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  DataCell(
                    Text(
                      '₱${_fmt(balance)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color: status == 'overdue' ? AppColors.error : null,
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_freqLabel(freq),
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text('₱${_fmt(payAmt)}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  DataCell(StatusBadge(status: status, type: 'loan')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // View details
                        _TableActionBtn(
                          icon:    Icons.visibility_rounded,
                          color:   AppColors.info,
                          tooltip: 'View Details',
                          onTap:   () => _showLoanDetail(context, loan),
                        ),
                        const SizedBox(width: 4),
                        // Approve (only for pending/under_ci)
                        if (['pending', 'under_ci'].contains(status))
                          _TableActionBtn(
                            icon:    Icons.check_circle_outline_rounded,
                            color:   AppColors.success,
                            tooltip: 'Approve / Reject',
                            onTap:   () => _showApproveModal(context, loan, onRefresh),
                          ),
                        // Assign CI (pending only)
                        if (status == 'pending')
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _TableActionBtn(
                              icon:    Icons.person_search_rounded,
                              color:   AppColors.accent,
                              tooltip: 'Assign CI Rider',
                              onTap:   () => _showAssignCIModal(context, loan, onRefresh),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _freqLabel(String f) {
    switch (f) {
      case 'daily':   return 'Daily';
      case 'weekly':  return 'Weekly';
      case 'monthly': return 'Monthly';
      default:        return f;
    }
  }

  void _showLoanDetail(BuildContext context, Map<String, dynamic> loan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoanDetailModal(loan: loan),
    );
  }

  void _showApproveModal(BuildContext context, Map<String, dynamic> loan, VoidCallback onRefresh) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApproveLoanModal(loan: loan, onSuccess: onRefresh),
    );
  }

  void _showAssignCIModal(BuildContext context, Map<String, dynamic> loan, VoidCallback onRefresh) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignCIModal(loanId: loan['id'] as String, loanCode: loan['loan_code'] as String, onSuccess: onRefresh),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Table Action Button
// ─────────────────────────────────────────────────────────────

class _TableActionBtn extends StatefulWidget {
  final IconData icon;
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;
  const _TableActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  State<_TableActionBtn> createState() => _TableActionBtnState();
}

class _TableActionBtnState extends State<_TableActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor:  SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:        _hovered ? widget.color.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pagination Row
// ─────────────────────────────────────────────────────────────

class _PaginationRow extends StatelessWidget {
  final int  page;
  final bool hasMore;
  final VoidCallback onPrev, onNext;
  const _PaginationRow({required this.page, required this.hasMore, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page ${page + 1}',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          IconButton(
            onPressed: page > 0 ? onPrev : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          IconButton(
            onPressed: hasMore ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}