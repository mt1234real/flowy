import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Stationary lighting behind tab content; no blur or animation on scroll.
class AmbientCanvas extends ConsumerWidget {
  const AmbientCanvas({super.key, required this.child, this.dashboard = false});

  final Widget child;
  final bool dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider).primary;
    final base = isDark ? const Color(0xFF0F172A) : const Color(0xFFF7FAF9);
    final strength = dashboard ? (isDark ? .08 : .09) : (isDark ? .05 : .055);
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: ColoredBox(
              color: base,
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: dashboard ? 1 : .30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(.6, -.95),
                        radius: 1.2,
                        // Opaque endpoints avoid blending with unrelated routes.
                        colors: [
                          Color.alphaBlend(
                              accent.withValues(alpha: strength), base),
                          base
                        ],
                      ),
                    ),
                    child: dashboard
                        ? const SizedBox.expand()
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [base.withValues(alpha: 0), base],
                                stops: const [.45, 1],
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ]);
  }
}
