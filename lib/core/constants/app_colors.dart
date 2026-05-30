// lib/core/constants/app_colors.dart
// Jireta Loans & Credit Corp. 1996

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand / Primary (Sky Blue) ───────────────────────────
  static const Color primary50  = Color(0xFFf0f9ff);
  static const Color primary100 = Color(0xFFe0f2fe);
  static const Color primary200 = Color(0xFFbae6fd);
  static const Color primary300 = Color(0xFF7dd3fc);
  static const Color primary400 = Color(0xFF38bdf8);
  static const Color primary500 = Color(0xFF0ea5e9); // Main brand
  static const Color primary600 = Color(0xFF0284c7);
  static const Color primary700 = Color(0xFF0369a1);
  static const Color primary800 = Color(0xFF075985);
  static const Color primary900 = Color(0xFF0c4a6e);

  // ─── Accent / Secondary ───────────────────────────────────
  static const Color accent       = Color(0xFF06b6d4);   // Cyan
  static const Color accentLight  = Color(0xFFcffafe);
  static const Color accentDark   = Color(0xFF0e7490);

  // ─── Semantic Colors ──────────────────────────────────────
  static const Color success      = Color(0xFF10b981);
  static const Color successLight = Color(0xFFd1fae5);
  static const Color successDark  = Color(0xFF065f46);

  static const Color warning      = Color(0xFFf59e0b);
  static const Color warningLight = Color(0xFFfef3c7);
  static const Color warningDark  = Color(0xFF92400e);

  static const Color error        = Color(0xFFef4444);
  static const Color errorLight   = Color(0xFFfee2e2);
  static const Color errorDark    = Color(0xFF991b1b);

  static const Color info         = Color(0xFF3b82f6);
  static const Color infoLight    = Color(0xFFdbeafe);
  static const Color infoDark     = Color(0xFF1e40af);

  // ─── Loan Status Colors ───────────────────────────────────
  static const Color statusPending   = Color(0xFFf59e0b);
  static const Color statusUnderCI   = Color(0xFF8b5cf6);
  static const Color statusApproved  = Color(0xFF10b981);
  static const Color statusRejected  = Color(0xFFef4444);
  static const Color statusActive    = Color(0xFF0ea5e9);
  static const Color statusOverdue   = Color(0xFFf97316);
  static const Color statusCompleted = Color(0xFF6b7280);
  static const Color statusFrozen    = Color(0xFF64748b);

  // ─── Light Mode ───────────────────────────────────────────
  static const Color lightBackground     = Color(0xFFf8fafc);
  static const Color lightSurface        = Color(0xFFffffff);
  static const Color lightSurfaceVariant = Color(0xFFf1f5f9);
  static const Color lightBorder         = Color(0xFFe2e8f0);
  static const Color lightBorderLight    = Color(0xFFf1f5f9);
  static const Color lightText           = Color(0xFF0f172a);
  static const Color lightTextSecondary  = Color(0xFF475569);
  static const Color lightTextHint       = Color(0xFF94a3b8);
  static const Color lightSidebar        = Color(0xFFffffff);
  static const Color lightSidebarBorder  = Color(0xFFe2e8f0);
  static const Color lightCard           = Color(0xFFffffff);
  static const Color lightCardShadow     = Color(0x0F0f172a);

  // ─── Dark Mode ────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0a0f1e);
  static const Color darkSurface        = Color(0xFF111827);
  static const Color darkSurfaceVariant = Color(0xFF1e293b);
  static const Color darkBorder         = Color(0xFF1e293b);
  static const Color darkBorderLight    = Color(0xFF334155);
  static const Color darkText           = Color(0xFFf1f5f9);
  static const Color darkTextSecondary  = Color(0xFF94a3b8);
  static const Color darkTextHint       = Color(0xFF475569);
  static const Color darkSidebar        = Color(0xFF111827);
  static const Color darkSidebarBorder  = Color(0xFF1e293b);
  static const Color darkCard           = Color(0xFF1e293b);
  static const Color darkCardShadow     = Color(0x3F000000);

  // ─── Gradient ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary500, primary700],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary500],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary800, primary600],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0ea5e9), Color(0xFF0284c7)],
  );

  // ─── Shadows ──────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary500.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // ─── Status color helper ───────────────────────────────────
  static Color loanStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return statusPending;
      case 'under_ci':  return statusUnderCI;
      case 'approved':  return statusApproved;
      case 'rejected':  return statusRejected;
      case 'active':    return statusActive;
      case 'overdue':   return statusOverdue;
      case 'completed': return statusCompleted;
      case 'frozen':    return statusFrozen;
      default:          return statusPending;
    }
  }

  static Color collectionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return statusPending;
      case 'assigned':  return info;
      case 'collecting':return statusActive;
      case 'completed': return statusCompleted;
      case 'failed':    return statusRejected;
      default:          return statusPending;
    }
  }
}