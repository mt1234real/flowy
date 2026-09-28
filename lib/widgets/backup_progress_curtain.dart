import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/animation/app_animation_policy.dart';

var backupNavigatorKey = GlobalKey<NavigatorState>();
final backupOperationProvider = StateProvider<String?>((ref) => null);

/// The modal route blocks Android Back as well as touches on underlying sheets.
class BackupProgressHost extends ConsumerStatefulWidget {
  final Widget child;
  const BackupProgressHost({super.key, required this.child});
  @override
  ConsumerState<BackupProgressHost> createState() => _BackupProgressHostState();
}

class _BackupProgressHostState extends ConsumerState<BackupProgressHost> {
  Route<void>? _route;
  void _sync() {
    if (!mounted) return;
    final busy = ref.read(backupOperationProvider) != null;
    final navigator = backupNavigatorKey.currentState;
    if (navigator == null) return;
    if (busy && _route == null) {
      final route = PreservedDialogRoute<void>(
        barrierDismissible: false,
        reverseDuration: const Duration(milliseconds: 200),
        barrierColor: Colors.black.withValues(alpha: .60),
        builder: (context) => PopScope(
          canPop: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Dialog(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Consumer(
                    builder: (context, ref, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_sync_outlined, size: 32),
                            const SizedBox(height: 20),
                            Text(
                                ref.watch(backupOperationProvider) ??
                                    'Đã hoàn tất',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(minHeight: 2),
                            const SizedBox(height: 16),
                            const Text('Vui lòng giữ ứng dụng mở.',
                                textAlign: TextAlign.center),
                          ],
                        )),
              ),
            ),
          ),
        ),
      );
      _route = route;
      navigator.push(route);
    } else if (!busy && _route != null) {
      final route = _route!;
      _route = null;
      if (route.isCurrent) {
        navigator.pop();
      } else if (route.isActive) {
        navigator.removeRoute(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(backupOperationProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    });
    return widget.child;
  }
}
