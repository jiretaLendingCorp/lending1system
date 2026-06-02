// lib/utils/safe_hover_widget.dart

import 'package:flutter/material.dart';

class SafeHoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? hoverColor;
  final Color? splashColor;
  final EdgeInsetsGeometry? padding;

  const SafeHoverButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.splashColor,
    this.padding,
  });

  @override
  State<SafeHoverButton> createState() => _SafeHoverButtonState();
}

class _SafeHoverButtonState extends State<SafeHoverButton> {
  bool _isHovered = false;

  void _setHovered(bool hovered) {
    if (!mounted || _isHovered == hovered) return;
    setState(() => _isHovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.hoverColor ?? Theme.of(context).hoverColor)
              : Colors.transparent,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            splashColor: widget.splashColor,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
