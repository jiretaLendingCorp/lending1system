// lib/presentation/mobile/pages/loans/loan_application_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class LoanApplicationPage extends ConsumerStatefulWidget {
  const LoanApplicationPage({super.key});

  @override
  ConsumerState<LoanApplicationPage> createState() =>
      _LoanApplicationPageState();
}

class _LoanApplicationPageState extends ConsumerState<LoanApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // Step 1 – Personal Info
  final _borrowerName = TextEditingController();
  final _borrowerPhone = TextEditingController();
  final _borrowerAddress = TextEditingController();
  final _borrowerAge = TextEditingController();
  String _borrowerGender = 'male';

  // Step 2 – Loan Details
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  int _termDays = 30;
  double _interestRate = 5.0;
  double get _computedInterest =>
      (double.tryParse(_amount.text) ?? 0) * (_interestRate / 100);
  double get _totalPayable =>
      (double.tryParse(_amount.text) ?? 0) + _computedInterest;

  // Step 3 – Co-borrower (optional)
  bool _hasCoBorrower = false;
  final _coName = TextEditingController();
  final _coPhone = TextEditingController();
  final _coRelation = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _borrowerName.dispose();
    _borrowerPhone.dispose();
    _borrowerAddress.dispose();
    _borrowerAge.dispose();
    _amount.dispose();
    _purpose.dispose();
    _coName.dispose();
    _coPhone.dispose();
    _coRelation.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;

      // Generate loan number
      final count = await Supabase.instance.client
          .from('loans')
          .select('id', const FetchOptions(count: CountOption.exact));
      final loanNumber =
          'LN${DateFormat('yyyyMM').format(DateTime.now())}${((count.count ?? 0) + 1).toString().padLeft(4, '0')}';

      await Supabase.instance.client.from('loans').insert({
        'loan_number': loanNumber,
        'borrower_name': _borrowerName.text.trim(),
        'borrower_phone': _borrowerPhone.text.trim(),
        'borrower_address': _borrowerAddress.text.trim(),
        'borrower_age': int.tryParse(_borrowerAge.text) ?? 0,
        'borrower_gender': _borrowerGender,
        'amount': double.tryParse(_amount.text) ?? 0,
        'purpose': _purpose.text.trim(),
        'term_days': _termDays,
        'interest_rate': _interestRate,
        'interest_amount': _computedInterest,
        'total_payable': _totalPayable,
        'status': 'pending',
        'lender_id': uid,
        'created_at': DateTime.now().toIso8601String(),
        if (_hasCoBorrower && _coName.text.isNotEmpty) ...{
          'co_borrower_name': _coName.text.trim(),
          'co_borrower_phone': _coPhone.text.trim(),
          'co_borrower_relation': _coRelation.text.trim(),
        },
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Application Submitted!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Loan #$loanNumber has been submitted for review.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ]),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/mobile/loans');
                  },
                  child: const Text('View My Loans'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Application'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _prevPage,
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: i < _currentPage
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: i == _currentPage
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                      ),
                    ),
                    if (i < 2)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 2,
                          color: i < _currentPage
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ),

          // Page labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Personal\nInfo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: _currentPage >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey)),
                Text('Loan\nDetails',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: _currentPage >= 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey)),
                Text('Co-Borrower\n& Review',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: _currentPage >= 2
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _Step1(
                    nameCtrl: _borrowerName,
                    phoneCtrl: _borrowerPhone,
                    addressCtrl: _borrowerAddress,
                    ageCtrl: _borrowerAge,
                    gender: _borrowerGender,
                    onGenderChanged: (v) =>
                        setState(() => _borrowerGender = v),
                  ),
                  _Step2(
                    amountCtrl: _amount,
                    purposeCtrl: _purpose,
                    termDays: _termDays,
                    interestRate: _interestRate,
                    onTermChanged: (v) =>
                        setState(() => _termDays = v),
                    onRateChanged: (v) =>
                        setState(() => _interestRate = v),
                    computedInterest: _computedInterest,
                    totalPayable: _totalPayable,
                  ),
                  _Step3(
                    hasCoBorrower: _hasCoBorrower,
                    onToggle: (v) =>
                        setState(() => _hasCoBorrower = v),
                    coNameCtrl: _coName,
                    coPhoneCtrl: _coPhone,
                    coRelationCtrl: _coRelation,
                    // Review summary
                    borrowerName: _borrowerName.text,
                    amount: double.tryParse(_amount.text) ?? 0,
                    totalPayable: _totalPayable,
                    termDays: _termDays,
                  ),
                ],
              ),
            ),
          ),

          // Bottom button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _nextPage,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _currentPage < 2 ? 'Continue' : 'Submit Application',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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

// ── Step widgets ──────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl, addressCtrl, ageCtrl;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  const _Step1({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.ageCtrl,
    required this.gender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Enter the borrower\'s personal details',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 20),
          _Field(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline,
              validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          _Field(ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined,
              type: TextInputType.phone),
          const SizedBox(height: 14),
          _Field(ctrl: addressCtrl, label: 'Home Address', icon: Icons.home_outlined,
              maxLines: 2, validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _Field(ctrl: ageCtrl, label: 'Age', icon: Icons.cake_outlined,
                  type: TextInputType.number),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: gender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (v) => onGenderChanged(v!),
              ),
            ),
          ]),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _Step2 extends StatelessWidget {
  final TextEditingController amountCtrl, purposeCtrl;
  final int termDays;
  final double interestRate, computedInterest, totalPayable;
  final ValueChanged<int> onTermChanged;
  final ValueChanged<double> onRateChanged;
  const _Step2({
    required this.amountCtrl,
    required this.purposeCtrl,
    required this.termDays,
    required this.interestRate,
    required this.computedInterest,
    required this.totalPayable,
    required this.onTermChanged,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Loan Details',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Specify the loan amount and terms',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 20),
        _Field(
          ctrl: amountCtrl,
          label: 'Loan Amount (₱)',
          icon: Icons.monetization_on_outlined,
          type: TextInputType.number,
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Enter a valid amount';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _Field(ctrl: purposeCtrl, label: 'Purpose of Loan',
            icon: Icons.description_outlined, maxLines: 2,
            validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: termDays,
          decoration: InputDecoration(
            labelText: 'Loan Term',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          items: const [
            DropdownMenuItem(value: 15, child: Text('15 days')),
            DropdownMenuItem(value: 30, child: Text('30 days')),
            DropdownMenuItem(value: 45, child: Text('45 days')),
            DropdownMenuItem(value: 60, child: Text('60 days')),
            DropdownMenuItem(value: 90, child: Text('90 days')),
          ],
          onChanged: (v) => onTermChanged(v!),
        ),
        const SizedBox(height: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Interest Rate',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Text('${interestRate.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: interestRate,
            min: 1,
            max: 20,
            divisions: 38,
            onChanged: onRateChanged,
          ),
        ]),
        const SizedBox(height: 14),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            _SummaryRow('Principal Amount',
                '₱${NumberFormat('#,##0.00').format(double.tryParse(amountCtrl.text) ?? 0)}'),
            _SummaryRow('Interest (${interestRate.toStringAsFixed(1)}%)',
                '₱${NumberFormat('#,##0.00').format(computedInterest)}'),
            const Divider(),
            _SummaryRow('Total Payable',
                '₱${NumberFormat('#,##0.00').format(totalPayable)}',
                bold: true),
          ]),
        ),
      ]).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _Step3 extends StatelessWidget {
  final bool hasCoBorrower;
  final ValueChanged<bool> onToggle;
  final TextEditingController coNameCtrl, coPhoneCtrl, coRelationCtrl;
  final String borrowerName;
  final double amount, totalPayable;
  final int termDays;
  const _Step3({
    required this.hasCoBorrower,
    required this.onToggle,
    required this.coNameCtrl,
    required this.coPhoneCtrl,
    required this.coRelationCtrl,
    required this.borrowerName,
    required this.amount,
    required this.totalPayable,
    required this.termDays,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Review summary
        Text('Review & Co-Borrower',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Review your application before submitting',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            _SummaryRow('Borrower', borrowerName.isEmpty ? '-' : borrowerName),
            _SummaryRow('Loan Amount',
                '₱${NumberFormat('#,##0.00').format(amount)}'),
            _SummaryRow('Total Payable',
                '₱${NumberFormat('#,##0.00').format(totalPayable)}',
                bold: true),
            _SummaryRow('Term', '$termDays days'),
          ]),
        ),
        const SizedBox(height: 20),
        // Co-borrower toggle
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Co-Borrower',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Text('Optional guarantor/co-signer',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          Switch(value: hasCoBorrower, onChanged: onToggle),
        ]),
        if (hasCoBorrower) ...[
          const SizedBox(height: 16),
          _Field(ctrl: coNameCtrl, label: 'Co-Borrower Name',
              icon: Icons.person_add_outlined),
          const SizedBox(height: 14),
          _Field(ctrl: coPhoneCtrl, label: 'Co-Borrower Phone',
              icon: Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 14),
          _Field(ctrl: coRelationCtrl, label: 'Relationship',
              icon: Icons.family_restroom),
        ],
      ]).animate().fadeIn(duration: 300.ms),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      validator: validator,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade700, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: bold ? 15 : 13)),
        ],
      ),
    );
  }
}