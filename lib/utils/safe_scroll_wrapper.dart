// lib/utils/safe_scroll_wrapper.dart

import 'package:flutter/material.dart';

class SafeScrollWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SafeScrollWrapper({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

class SafeListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  const SafeListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        controller: controller,
        padding: padding ?? EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

class SafeListViewBuilder<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final Widget? emptyState;

  const SafeListViewBuilder({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyState != null) {
      return Expanded(
        child: Center(child: emptyState!),
      );
    }

    return Expanded(
      child: ListView.builder(
        controller: controller,
        padding: padding ?? EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (ctx, i) => itemBuilder(ctx, items[i], i),
      ),
    );
  }
}