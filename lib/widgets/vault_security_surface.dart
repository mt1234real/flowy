import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/animation/app_animation_policy.dart';

/// Shared canvas; scrolls on short screens while keeping the keypad anchored
/// at the bottom when there is sufficient height.
class VaultSecuritySurface extends StatelessWidget {
  final Widget child;
  const VaultSecuritySurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 0.85,
            colors: [Color(0xFF111622), Color(0xFF080B11)],
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class VaultBreathingShield extends StatefulWidget {
  final Color accent;
  const VaultBreathingShield({super.key, required this.accent});

  @override
  State<VaultBreathingShield> createState() => _VaultBreathingShieldState();
}

class _VaultBreathingShieldState extends State<VaultBreathingShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing;

  @override
  void initState() {
    super.initState();
    _breathing = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(seconds: 3),
      debugLabel: 'VaultSecurity.breathingShield',
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              width: 256,
              height: 180,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _breathing,
                    builder: (context, _) {
                      final t =
                          Curves.easeInOutSine.transform(_breathing.value);
                      return Transform.scale(
                        scale: (112 + 16 * t) / 128,
                        child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(128),
                              color: widget.accent
                                  .withValues(alpha: 0.14 + 0.04 * t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          width: 0.8,
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Center(
                        child: Icon(Icons.shield_outlined,
                            size: 32, color: widget.accent)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
