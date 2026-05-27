// lib/core/utils/validators.dart
// Jireta Loans & Credit Corp. 1996 — Strict Form Validators

import '../constants/app_constants.dart';

class AppValidators {
  AppValidators._();

  // ─── Required ─────────────────────────────────────────────
  static String? required(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'This field'} is required';
    }
    return null;
  }

  // ─── Name ─────────────────────────────────────────────────
  static String? name(String? value, {String? label}) {
    final l = label ?? 'Name';
    if (value == null || value.trim().isEmpty) return '$l is required';
    final v = value.trim();
    if (v.length < AppConstants.minNameLength) {
      return '$l must be at least ${AppConstants.minNameLength} characters';
    }
    if (v.length > AppConstants.maxNameLength) {
      return '$l must not exceed ${AppConstants.maxNameLength} characters';
    }
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s'\-\.]+$").hasMatch(v)) {
      return '$l contains invalid characters';
    }
    return null;
  }

  // ─── Email (strict) ───────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final v = value.trim().toLowerCase();
    if (!AppConstants.emailRegex.hasMatch(v)) {
      return 'Enter a valid email address';
    }
    if (v.length > 254) return 'Email is too long';
    return null;
  }

  // ─── Email (loose — admin only) ───────────────────────────
  static String? emailAdmin(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (value.trim().length > 254) return 'Email is too long';
    return null;
  }

  // ─── Password (strict) ────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'(?=.*[@$!%*?&_#^()\-+=])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  // ─── Password (loose — admin only) ────────────────────────
  static String? passwordAdmin(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  // ─── Confirm Password ─────────────────────────────────────
  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  // ─── Philippine Phone Number ──────────────────────────────
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final v = value.trim().replaceAll(' ', '').replaceAll('-', '');
    if (!AppConstants.phoneRegex.hasMatch(v)) {
      return 'Enter a valid Philippine phone number (09XXXXXXXXX)';
    }
    return null;
  }

  // ─── Loan Amount ──────────────────────────────────────────
  static String? loanAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Loan amount is required';
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null) return 'Enter a valid amount';
    if (amount < AppConstants.minLoanAmount) {
      return 'Minimum loan amount is ₱${AppConstants.minLoanAmount.toStringAsFixed(0)}';
    }
    if (amount > AppConstants.maxLoanAmount) {
      return 'Maximum loan amount is ₱${AppConstants.maxLoanAmount.toStringAsFixed(0)}';
    }
    return null;
  }

  // ─── Positive Number ──────────────────────────────────────
  static String? positiveNumber(String? value, {String? label, double? min, double? max}) {
    final l = label ?? 'Value';
    if (value == null || value.trim().isEmpty) return '$l is required';
    final n = double.tryParse(value.replaceAll(',', ''));
    if (n == null) return '$l must be a valid number';
    if (n <= 0) return '$l must be greater than 0';
    if (min != null && n < min) return '$l must be at least $min';
    if (max != null && n > max) return '$l must not exceed $max';
    return null;
  }

  // ─── Interest Rate ────────────────────────────────────────
  static String? interestRate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Interest rate is required';
    final rate = double.tryParse(value);
    if (rate == null) return 'Enter a valid interest rate';
    if (rate < 0)   return 'Interest rate cannot be negative';
    if (rate > 100) return 'Interest rate cannot exceed 100%';
    return null;
  }

  // ─── Date of Birth ────────────────────────────────────────
  static String? dateOfBirth(DateTime? value) {
    if (value == null) return 'Date of birth is required';
    final now = DateTime.now();
    final age = now.year - value.year -
        ((now.month < value.month ||
                (now.month == value.month && now.day < value.day))
            ? 1 : 0);
    if (age < 18) return 'You must be at least 18 years old';
    if (age > 100) return 'Enter a valid date of birth';
    return null;
  }

  // ─── Future Date ──────────────────────────────────────────
  static String? futureDate(DateTime? value, {String? label}) {
    if (value == null) return '${label ?? 'Date'} is required';
    if (value.isBefore(DateTime.now())) {
      return '${label ?? 'Date'} must be in the future';
    }
    return null;
  }

  // ─── Text Length ──────────────────────────────────────────
  static String? textLength(
    String? value, {
    String? label,
    int? min,
    int? max,
    bool required = true,
  }) {
    final l = label ?? 'This field';
    if (value == null || value.trim().isEmpty) {
      return required ? '$l is required' : null;
    }
    final v = value.trim();
    if (min != null && v.length < min) {
      return '$l must be at least $min characters';
    }
    if (max != null && v.length > max) {
      return '$l must not exceed $max characters';
    }
    return null;
  }

  // ─── Remarks / Text Area ──────────────────────────────────
  static String? remarks(String? value, {bool required = true}) {
    if (!required && (value == null || value.trim().isEmpty)) return null;
    return textLength(value,
        label: 'Remarks',
        min:   AppConstants.minRemarksLength,
        max:   1000,
        required: required);
  }

  // ─── Dropdown ─────────────────────────────────────────────
  static String? dropdown<T>(T? value, {String? label}) {
    if (value == null) return '${label ?? 'Selection'} is required';
    if (value is String && value.trim().isEmpty) {
      return '${label ?? 'Selection'} is required';
    }
    return null;
  }

  // ─── File Upload ──────────────────────────────────────────
  static String? fileSize(int? fileSizeBytes) {
    if (fileSizeBytes == null) return 'File is required';
    if (fileSizeBytes > AppConstants.maxFileSizeBytes) {
      return 'File size must not exceed ${AppConstants.maxFileSizeMb}MB';
    }
    return null;
  }

  static String? fileExtension(String? fileName, {bool allowPdf = true}) {
    if (fileName == null || fileName.isEmpty) return 'File is required';
    final ext = fileName.split('.').last.toLowerCase();
    final allowed = allowPdf
        ? AppConstants.allowedDocExtensions
        : AppConstants.allowedImageExtensions;
    if (!allowed.contains(ext)) {
      return 'Only ${allowed.join(', ').toUpperCase()} files are allowed';
    }
    return null;
  }

  // ─── Employee Code ────────────────────────────────────────
  static String? employeeCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Employee code is required';
    if (!RegExp(r'^EMP-\d{6,}$').hasMatch(value.trim())) {
      return 'Invalid employee code format (EMP-XXXXXX)';
    }
    return null;
  }

  // ─── License Number ───────────────────────────────────────
  static String? licenseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'License number is required';
    final v = value.trim();
    if (v.length < 5 || v.length > 20) {
      return 'License number must be 5-20 characters';
    }
    return null;
  }

  // ─── Vehicle Plate ────────────────────────────────────────
  static String? vehiclePlate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Plate number is required';
    final v = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{3,8}$').hasMatch(v.replaceAll(' ', ''))) {
      return 'Enter a valid plate number';
    }
    return null;
  }

  // ─── Monthly Income ───────────────────────────────────────
  static String? monthlyIncome(String? value) {
    if (value == null || value.trim().isEmpty) return 'Monthly income is required';
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null || amount <= 0) return 'Enter a valid income amount';
    if (amount < 1000) return 'Monthly income seems too low';
    return null;
  }

  // ─── Zip Code (PH) ────────────────────────────────────────
  static String? zipCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'ZIP code is required';
    if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
      return 'Enter a valid 4-digit Philippine ZIP code';
    }
    return null;
  }

  // ─── Year ─────────────────────────────────────────────────
  static String? year(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'Year'} is required';
    }
    final y = int.tryParse(value.trim());
    if (y == null) return 'Enter a valid year';
    if (y < 1950 || y > DateTime.now().year + 1) {
      return 'Enter a valid year between 1950 and ${DateTime.now().year + 1}';
    }
    return null;
  }
}