// lib/presentation/mobile/pages/loans/loan_application_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

const double _fixedInterestRate = AppConstants.defaultInterest;

class LoanApplicationPage extends ConsumerStatefulWidget {
  const LoanApplicationPage({super.key});

  @override
  ConsumerState<LoanApplicationPage> createState() => _LoanApplicationPageState();
}

class _LoanApplicationPageState extends ConsumerState<LoanApplicationPage> {
  final _formKey  = GlobalKey<FormState>();
  final _pageCtrl = PageController();
  int _currentPage = 0;

  final _amountCtrl  = TextEditingController();
  final _purposeCtrl = TextEditingController();
  int    _termDays           = 30;
  String _paymentFrequency   = 'monthly';

  bool _loading = false;

  double get _principal      => double.tryParse(_amountCtrl.text) ?? 0;
  double get _totalInterest  => _principal * (_fixedInterestRate / 100);
  double get _totalPayable   => _principal + _totalInterest;
  double get _paymentAmount  => _computePaymentAmount();

  double _computePaymentAmount() {
    if (_totalPayable <= 0) return 0;
    switch (_paymentFrequency) {
      case 'daily':   return _totalPayable / _termDays;
      case 'weekly':  return _totalPayable / (_termDays / 7).ceil();
      case 'monthly': return _totalPayable / (_termDays / 30).ceil();
      default:        return _totalPayable;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      if (!_formKey.currentState!.validate()) return;
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid == null) throw Exception('Not authenticated');

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('User profile not found');

      final lenderRow = await Supabase.instance.client
          .from('lenders')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (lenderRow == null) throw Exception('Lender profile not found. Contact admin.');

      final lenderId = lenderRow['id'] as String;

      final countResp = await Supabase.instance.client
          .from('loans')
          .select('id')
          .count(CountOption.exact);

      final loanCode = 'LN${DateFormat('yyyyMM').format(DateTime.now())}${((countResp.count) + 1).toString().padLeft(4, '0')}';

      await Supabase.instance.client.from('loans').insert({
        'loan_code':          loanCode,
        'lender_id':          lenderId,
        'principal_amount':   _principal,
        'interest_rate':      _fixedInterestRate,
        'total_interest':     _totalInterest,
        'total_payable':      _totalPayable,
        'processing_fee':     0,
        'service_fee':        0,
        'ci_fee':             0,
        'total_charges':      0,
        'net_disbursement':   _principal,
        'payment_frequency':  _paymentFrequency,
        'term_days':          _termDays,
        'payment_amount':     _paymentAmount,
        'outstanding_balance':_totalPayable,
        'loan_status':        'pending',
        'purpose':            _purposeCtrl.text.trim(),
      });

      if (mounted) {
        showDialog(
          context:            context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Application Submitted!',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Loan #$loanCode has been submitted for review.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
            ]),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () { Navigator.pop(context); context.go(AppConstants.routeLenderLoans); },
                  child: const Text('View My Loans', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Loan Application', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _prevPage,
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentPage: _currentPage),
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageCtrl,
                physics:    const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _StepLoanDetails(
                    amountCtrl:        _amountCtrl,
                    purposeCtrl:       _purposeCtrl,
                    termDays:          _termDays,
                    paymentFrequency:  _paymentFrequency,
                    totalInterest:     _totalInterest,
                    totalPayable:      _totalPayable,
                    onTermChanged:    (v) => setState(() => _termDays = v),
                    onFreqChanged:    (v) => setState(() => _paymentFrequency = v),
                    onAmountChanged:  () => setState(() {}),
                  ),
                  _StepReview(
                    principal:        _principal,
                    totalInterest:    _totalInterest,
                    totalPayable:     _totalPayable,
                    paymentAmount:    _paymentAmount,
                    termDays:         _termDays,
                    paymentFrequency: _paymentFrequency,
                    purpose:          _purposeCtrl.text,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width:  double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _nextPage,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _currentPage < 1 ? 'Continue' : 'Submit Application',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentPage;
  const _StepIndicator({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final labels = ['Loan Details', 'Review & Submit'];
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: i <= currentPage ? primary : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: i < currentPage
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Text('${i + 1}',
                              style: TextStyle(
                                color: i == currentPage ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 2,
                        color: i < currentPage ? primary : Colors.grey.shade300,
                      ),
                    ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((e) => Text(
              e.value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: e.key <= currentPage ? primary : Colors.grey,
                fontWeight: e.key == currentPage ? FontWeight.w600 : FontWeight.w400,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepLoanDetails extends StatelessWidget {
  final TextEditingController amountCtrl, purposeCtrl;
  final int    termDays;
  final String paymentFrequency;
  final double totalInterest, totalPayable;
  final ValueChanged<int>    onTermChanged;
  final ValueChanged<String> onFreqChanged;
  final VoidCallback         onAmountChanged;

  const _StepLoanDetails({
    required this.amountCtrl,
    required this.purposeCtrl,
    required this.termDays,
    required this.paymentFrequency,
    required this.totalInterest,
    required this.totalPayable,
    required this.onTermChanged,
    required this.onFreqChanged,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Loan Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Fill in the details for your loan application',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontFamily: 'Poppins')),
        const SizedBox(height: 20),

        TextFormField(
          controller:   amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:  'Loan Amount (₱)',
            hintText:   'Min ₱5,000 – Max ₱500,000',
            prefixIcon: const Icon(Icons.monetization_on_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          style: const TextStyle(fontFamily: 'Poppins'),
          onChanged: (_) => onAmountChanged(),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n < AppConstants.minLoanAmount) return 'Minimum ₱${fmt.format(AppConstants.minLoanAmount)}';
            if (n > AppConstants.maxLoanAmount) return 'Maximum ₱${fmt.format(AppConstants.maxLoanAmount)}';
            return null;
          },
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: purposeCtrl,
          maxLines:   2,
          decoration: InputDecoration(
            labelText:  'Purpose of Loan',
            prefixIcon: const Icon(Icons.description_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          style: const TextStyle(fontFamily: 'Poppins'),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 14),

        _StyledDropdown<int>(
          label:      'Loan Term',
          icon:       Icons.calendar_today_outlined,
          value:      termDays,
          items: const [
            DropdownMenuItem(value: 15, child: Text('15 days', style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 30, child: Text('30 days', style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 45, child: Text('45 days', style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 60, child: Text('60 days', style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 90, child: Text('90 days', style: TextStyle(fontFamily: 'Poppins'))),
          ],
          onChanged: onTermChanged,
        ),
        const SizedBox(height: 14),

        _StyledDropdown<String>(
          label:  'Payment Frequency',
          icon:   Icons.repeat_rounded,
          value:  paymentFrequency,
          items: const [
            DropdownMenuItem(value: 'daily',   child: Text('Daily',   style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 'weekly',  child: Text('Weekly',  style: TextStyle(fontFamily: 'Poppins'))),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(fontFamily: 'Poppins'))),
          ],
          onChanged: onFreqChanged,
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary600),
            const SizedBox(width: 8),
            Text('Interest rate is fixed at ${_fixedInterestRate.toStringAsFixed(0)}% by admin.',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary700)),
          ]),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            _SummaryRow('Principal',      '₱${fmt.format(double.tryParse(amountCtrl.text) ?? 0)}'),
            _SummaryRow('Interest (${_fixedInterestRate.toStringAsFixed(0)}%)', '₱${fmt.format(totalInterest)}'),
            const Divider(),
            _SummaryRow('Total Payable',  '₱${fmt.format(totalPayable)}', bold: true),
          ]),
        ),
      ]).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _StepReview extends StatelessWidget {
  final double principal, totalInterest, totalPayable, paymentAmount;
  final int    termDays;
  final String paymentFrequency, purpose;

  const _StepReview({
    required this.principal,
    required this.totalInterest,
    required this.totalPayable,
    required this.paymentAmount,
    required this.termDays,
    required this.paymentFrequency,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final freqLabel = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'}[paymentFrequency] ?? paymentFrequency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Review Application',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Please review before submitting',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontFamily: 'Poppins')),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: [
            _SummaryRow('Principal Amount',  '₱${fmt.format(principal)}'),
            _SummaryRow('Interest (${_fixedInterestRate.toStringAsFixed(0)}%)', '₱${fmt.format(totalInterest)}'),
            _SummaryRow('Total Payable',     '₱${fmt.format(totalPayable)}', bold: true),
            const Divider(height: 20),
            _SummaryRow('Term',              '$termDays days'),
            _SummaryRow('Payment Frequency', freqLabel),
            _SummaryRow('Payment per $freqLabel', '₱${fmt.format(paymentAmount)}'),
            _SummaryRow('Purpose',           purpose.isEmpty ? '—' : purpose),
          ]),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warningDark),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your application will be reviewed and subject to credit investigation before approval.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningDark),
              ),
            ),
          ]),
        ),
      ]).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool   bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade600, fontSize: 13)),
        Text(value,  style: TextStyle(fontFamily: 'Poppins', fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 15 : 13)),
      ]),
    );
  }
}

// Styled DropdownButton wrapper — avoids the deprecated DropdownButtonFormField.value param
class _StyledDropdown<T> extends StatelessWidget {
  final String                       label;
  final IconData                     icon;
  final T                            value;
  final List<DropdownMenuItem<T>>    items;
  final ValueChanged<T>              onChanged;

  const _StyledDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecorator(
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon),
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled:     true,
        fillColor:  isDark ? Colors.white10 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:       value,
          isExpanded:  true,
          items:       items,
          onChanged:   (v) { if (v != null) onChanged(v); },
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize:   14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}