// ==============================================================================
// File: lib/screens/main_scaffold.dart
//
// Root Navigation Shell Motion:
// - 4 bottom tabs:
//   + Haptic selectionClick
//   + Preserved icon scale 1.0 -> 1.18 -> 1.15 / 180ms
//   + Outline -> Filled crossfade
//   + Muted -> Accent color interpolation
//
// - Center Quick Entry button:
//   + Press 1.0 -> 0.93 / 80ms
//   + lightImpact on press
//   + Release 0.93 -> 1.02 -> 1.0 / 120ms
//   + QuickEntrySheet.show() launches near rebound peak (Fluid Sheet Engine)
//
// - IndexedStack stays structurally fixed.
// - Inactive tabs get TickerMode(false) to stop hidden motion.
// - All critical animation controllers use AnimationBehavior.preserve.
// ==============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_entry_sheet.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'ledger_screen.dart';
import 'settings_screen.dart';

// ==============================================================================
// GLOBAL TAB PROVIDER
// ==============================================================================

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ==============================================================================
// MOTION TOKENS
// ==============================================================================

abstract final class MainShellMotion {
  // Bottom navigation
  static const navSelect = Duration(milliseconds: 180);
  static const navDeselect = Duration(milliseconds: 140);
  static const navIconMorph = Duration(milliseconds: 150);

  // FAB
  static const fabPress = Duration(milliseconds: 80);
  static const fabRelease = Duration(milliseconds: 120);

  // Quick Entry modal
  static const sheetIn = Duration(milliseconds: 270);
  static const sheetOut = Duration(milliseconds: 240);
}

// ==============================================================================
// MAIN SCAFFOLD
// ==============================================================================

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({
    super.key,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with TickerProviderStateMixin {
  static const List<Widget> _screens = [
    DashboardScreen(),
    LedgerScreen(),
    BudgetScreen(),
    SettingsScreen(),
  ];

  // ============================================================================
  // QUICK ENTRY LAUNCHER: Ủy quyền cho Fluid Sheet Engine
  // ============================================================================

  Future<void> _openQuickEntry() async {
    await QuickEntrySheet.show(context);
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final currentTabIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,

      // ========================================================================
      // CONTENT
      // ========================================================================

      body: IndexedStack(
        index: currentTabIndex,
        children: List.generate(
          _screens.length,
              (index) {
            return TickerMode(
              enabled: currentTabIndex == index,
              child: _screens[index],
            );
          },
        ),
      ),

      // ========================================================================
      // QUICK ENTRY FAB
      // ========================================================================

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _BouncyQuickEntryButton(
        accent: accent,
        onTriggered: _openQuickEntry,
      ),

      // ========================================================================
      // BOTTOM NAVIGATION
      // ========================================================================

      bottomNavigationBar: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 16,
              sigmaY: 16,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.darkCard.withValues(alpha: 0.85)
                    : AppTokens.lightCard.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // ===========================================================
                  // DASHBOARD
                  // ===========================================================

                  _PreservedNavTabItem(
                    selected: currentTabIndex == 0,
                    outlineIcon: Icons.dashboard_outlined,
                    filledIcon: Icons.dashboard_rounded,
                    label: 'Tổng quan',
                    accent: accent,
                    isDark: isDark,
                    onSelected: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 0;
                    },
                  ),

                  // ===========================================================
                  // LEDGER
                  // ===========================================================

                  _PreservedNavTabItem(
                    selected: currentTabIndex == 1,
                    outlineIcon: Icons.receipt_long_outlined,
                    filledIcon: Icons.receipt_long_rounded,
                    label: 'Sổ GD',
                    accent: accent,
                    isDark: isDark,
                    onSelected: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 1;
                    },
                  ),

                  // ===========================================================
                  // FAB GAP
                  // ===========================================================

                  const SizedBox(width: 44),

                  // ===========================================================
                  // BUDGET
                  // ===========================================================

                  _PreservedNavTabItem(
                    selected: currentTabIndex == 2,
                    outlineIcon: Icons.pie_chart_outline,
                    filledIcon: Icons.pie_chart_rounded,
                    label: 'Ngân sách',
                    accent: accent,
                    isDark: isDark,
                    onSelected: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 2;
                    },
                  ),

                  // ===========================================================
                  // SETTINGS
                  // ===========================================================

                  _PreservedNavTabItem(
                    selected: currentTabIndex == 3,
                    outlineIcon: Icons.settings_outlined,
                    filledIcon: Icons.settings_rounded,
                    label: 'Cài đặt',
                    accent: accent,
                    isDark: isDark,
                    onSelected: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 3;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// PRESERVED BOTTOM NAV TAB
// ==============================================================================

class _PreservedNavTabItem extends StatefulWidget {
  final bool selected;
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final AppAccentPreset accent;
  final bool isDark;
  final VoidCallback onSelected;

  const _PreservedNavTabItem({
    required this.selected,
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onSelected,
  });

  @override
  State<_PreservedNavTabItem> createState() => _PreservedNavTabItemState();
}

class _PreservedNavTabItemState extends State<_PreservedNavTabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: MainShellMotion.navSelect,
      reverseDuration: MainShellMotion.navDeselect,
      debugLabel: 'MainShell.Nav.${widget.label}',
    );

    _controller.value = widget.selected ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant _PreservedNavTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selected == widget.selected) {
      return;
    }

    if (widget.selected) {
      _controller.forward(from: 0.0);
    } else {
      _controller.animateBack(
        0.0,
        duration: MainShellMotion.navDeselect,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================================
  // SCALE CURVE
  // ============================================================================

  double _resolveIconScale(double p) {
    if (!widget.selected) {
      return 1.0 + (0.15 * Curves.easeOut.transform(p));
    }

    const peakPoint = 0.72;

    if (p <= peakPoint) {
      final local = (p / peakPoint).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(local);
      return _lerp(1.0, 1.18, eased);
    }

    final local = ((p - peakPoint) / (1.0 - peakPoint)).clamp(0.0, 1.0);
    return _lerp(1.18, 1.15, Curves.easeOutCubic.transform(local));
  }

  double _lerp(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final selectedColor = widget.accent.primary;
    final mutedColor = widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted;

    return InkWell(
      onTapDown: (_) {
        if (!widget.selected) {
          HapticFeedback.selectionClick();
        }
      },
      onTap: () {
        if (widget.selected) {
          return;
        }
        widget.onSelected();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final p = _controller.value.clamp(0.0, 1.0);
            final scale = _resolveIconScale(p);

            final currentColor = Color.lerp(
              mutedColor,
              selectedColor,
              Curves.easeOut.transform(p),
            ) ??
                mutedColor;

            const morphEnd = 150.0 / 180.0;
            final iconMorph = Curves.easeOut.transform(
              (p / morphEnd).clamp(0.0, 1.0),
            );

            final labelWeight = FontWeight.lerp(
              FontWeight.w500,
              FontWeight.w700,
              p,
            ) ??
                FontWeight.w500;

            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1.0 - iconMorph,
                          child: Icon(
                            widget.outlineIcon,
                            size: 22,
                            color: currentColor,
                          ),
                        ),
                        Opacity(
                          opacity: iconMorph,
                          child: Icon(
                            widget.filledIcon,
                            size: 22,
                            color: currentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: labelWeight,
                    color: currentColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ==============================================================================
// BOUNCING QUICK ENTRY BUTTON
// ==============================================================================

class _BouncyQuickEntryButton extends StatefulWidget {
  final AppAccentPreset accent;
  final Future<void> Function() onTriggered;

  const _BouncyQuickEntryButton({
    required this.accent,
    required this.onTriggered,
  });

  @override
  State<_BouncyQuickEntryButton> createState() => _BouncyQuickEntryButtonState();
}

class _BouncyQuickEntryButtonState extends State<_BouncyQuickEntryButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _releaseController;

  bool _releasing = false;
  bool _triggerPending = false;
  bool _triggerSent = false;
  bool _sheetBusy = false;
  double _releaseStartScale = 1.0;

  @override
  void initState() {
    super.initState();

    _pressController = AppAnimationPolicy.createController(
      vsync: this,
      duration: MainShellMotion.fabPress,
      debugLabel: 'MainShell.FAB.press',
    );

    _releaseController = AppAnimationPolicy.createController(
      vsync: this,
      duration: MainShellMotion.fabRelease,
      debugLabel: 'MainShell.FAB.release',
    );

    _releaseController.addListener(_handleReleaseProgress);
  }

  @override
  void dispose() {
    _releaseController.removeListener(_handleReleaseProgress);
    _pressController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  double get _pressedScale {
    final p = Curves.easeOutQuad.transform(_pressController.value);
    return _lerp(1.0, 0.93, p);
  }

  double _resolveReleaseScale(double t) {
    const peakPoint = 80.0 / 120.0;

    if (t <= peakPoint) {
      final local = (t / peakPoint).clamp(0.0, 1.0);
      return _lerp(
        _releaseStartScale,
        1.02,
        Curves.easeOutQuad.transform(local),
      );
    }

    final local = ((t - peakPoint) / (1.0 - peakPoint)).clamp(0.0, 1.0);
    return _lerp(
      1.02,
      1.0,
      Curves.easeOutCubic.transform(local),
    );
  }

  double _lerp(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  void _handleTapDown(TapDownDetails details) {
    if (_sheetBusy) return;

    HapticFeedback.lightImpact();
    _releaseController.stop();

    _triggerPending = false;
    _triggerSent = false;

    if (_releasing) {
      setState(() {
        _releasing = false;
      });
    }

    _pressController.forward(from: 0.0);
  }

  void _handleTapCancel() {
    if (_sheetBusy) return;
    _startRelease(triggerSheet: false);
  }

  void _handleTap() {
    if (_sheetBusy) return;
    _startRelease(triggerSheet: true);
  }

  void _startRelease({required bool triggerSheet}) {
    _releaseStartScale = _pressedScale;
    _pressController.stop();

    _triggerPending = triggerSheet;
    _triggerSent = false;

    setState(() {
      _releasing = true;
    });

    _releaseController.forward(from: 0.0).whenComplete(() {
      if (!mounted) return;

      _pressController.value = 0.0;
      _releaseController.value = 0.0;

      setState(() {
        _releasing = false;
      });
    });
  }

  void _handleReleaseProgress() {
    if (!_triggerPending || _triggerSent || _sheetBusy) {
      return;
    }

    const triggerPoint = 80.0 / 120.0;

    if (_releaseController.value < triggerPoint) {
      return;
    }

    _triggerSent = true;
    _triggerPending = false;
    _sheetBusy = true;

    widget.onTriggered().whenComplete(() {
      _sheetBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pressController,
        _releaseController,
      ]),
      builder: (context, _) {
        final scale = _releasing
            ? _resolveReleaseScale(_releaseController.value)
            : _pressedScale;

        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accent.primary.withValues(alpha: 0.40),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: widget.accent.primary,
              elevation: 4,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTapDown: _handleTapDown,
                onTapCancel: _handleTapCancel,
                onTap: _handleTap,
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}