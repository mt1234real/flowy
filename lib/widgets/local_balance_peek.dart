import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/animation/app_animation_policy.dart';

/// Local disclosure never changes the screen privacy setting.
class LocalBalancePeek extends StatefulWidget {
  final bool visible;
  final Object valueKey;
  final Widget Function(bool visible) builder;
  const LocalBalancePeek(
      {super.key,
      required this.visible,
      required this.valueKey,
      required this.builder});
  @override
  State<LocalBalancePeek> createState() => _LocalBalancePeekState();
}

class _LocalBalancePeekState extends State<LocalBalancePeek>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
  bool _peek = false;
  int _epoch = 0;
  late final AnimationController _motion = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'Balance.peek')
    ..value = 1;
  void _reset() {
    _timer?.cancel();
    _peek = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant LocalBalancePeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.valueKey != widget.valueKey) {
      if (_peek && oldWidget.valueKey != widget.valueKey) _epoch++;
      _reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false ||
        !TickerMode.valuesOf(context).enabled) {
      _reset();
      _epoch++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() {
        _reset();
        _epoch++;
      });
    }
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() => _peek = !_peek);
    _motion.forward(from: 0);
    if (_peek) {
      _timer = Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        setState(() => _peek = false);
        _motion.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(
        key: ValueKey(_epoch), child: widget.builder(widget.visible || _peek));
    return Semantics(
        button: !widget.visible,
        hint: widget.visible
            ? null
            : (_peek ? 'Chạm để che lại' : 'Chạm để xem trong 3,5 giây'),
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.visible ? null : _toggle,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: _peek
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: FadeTransition(
                    opacity: Tween<double>(begin: .45, end: 1).animate(_motion),
                    child: child))));
  }
}
