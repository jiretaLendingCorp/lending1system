// lib/presentation/web/pages/widgets/web_data_table.dart
// Placeholder — used in loans_page.dart import

import 'package:flutter/material.dart';

// This file satisfies the import in loans_page.dart.
// Extend with pluto_grid or data_table_2 for production use.
class WebDataTable extends StatelessWidget {
  final List<String>               columns;
  final List<Map<String, dynamic>> rows;

  const WebDataTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}