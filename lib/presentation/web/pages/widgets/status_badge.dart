// lib/presentation/web/pages/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String type;   // 'loan' | 'collection' | 'ci'
  final bool   light;  // white text variant for dark backgrounds

  const StatusBadge({
    super.key,
    required this.status,
    this.type = 'loan',
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final label = _label();

    if (light) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Color _color() {
    if (type == 'loan') return AppColors.loanStatusColor(status);
    return AppColors.collectionStatusColor(status);
  }

  String _label() {
    switch (status) {
      case 'pending':    return 'Pending';
      case 'under_ci':  return 'Under CI';
      case 'approved':  return 'Approved';
      case 'rejected':  return 'Rejected';
      case 'active':    return 'Active';
      case 'overdue':   return 'Overdue';
      case 'completed': return 'Completed';
      case 'frozen':    return 'Frozen';
      case 'assigned':  return 'Assigned';
      case 'collecting':return 'Collecting';
      case 'failed':    return 'Failed';
      case 'ongoing':   return 'Ongoing';
      case 'reviewed':  return 'Reviewed';
      default:          return status;
    }
  }
}