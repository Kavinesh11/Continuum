import 'package:flutter/material.dart';

/// Counts taps within a window and fires [onTrigger] when the threshold is hit.
/// Wraps a child invisibly — layout is unchanged.
class EasterEggDetector extends StatefulWidget {
  final Widget child;
  final int taps;
  final Duration window;
  final VoidCallback onTrigger;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  const EasterEggDetector({
    Key? key,
    required this.child,
    required this.onTrigger,
    this.taps = 4,
    this.window = const Duration(seconds: 3),
    this.onLongPress,
    this.behavior = HitTestBehavior.translucent,
  }) : super(key: key);

  @override
  State<EasterEggDetector> createState() => _EasterEggDetectorState();
}

class _EasterEggDetectorState extends State<EasterEggDetector> {
  int _count = 0;
  DateTime? _firstTap;

  void _handleTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > widget.window) {
      _count = 1;
      _firstTap = now;
    } else {
      _count += 1;
    }
    if (_count >= widget.taps) {
      _count = 0;
      _firstTap = null;
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );
  }
}
