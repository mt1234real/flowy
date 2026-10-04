import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'backup_state.dart';

/// Application-scoped read gate. All observation consumers join the same
/// future, including consumers created while an earlier one is being removed.
class BackupStatusReadCoordinator {
  final Future<BackupStatus> Function() _read;
  Future<BackupStatus>? _inFlight;
  BackupStatusReadCoordinator(this._read);

  Future<BackupStatus> readFresh() {
    if (_inFlight != null) return _inFlight!;
    late final Future<BackupStatus> future;
    future = Future<BackupStatus>.sync(_read).whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    _inFlight = future;
    return future;
  }
}

/// One application-scoped observation engine, shared by the root pill and
/// Settings. It reads persistence only and polls only while listened to and
/// foregrounded; it never owns or changes the actual backup lifecycle.
class BackupStatusObservation with WidgetsBindingObserver {
  final BackupStatusReadCoordinator coordinator;
  final Stream<void> changes;
  late final StreamController<BackupStatus> _events;
  Stream<BackupStatus> get stream => _events.stream;
  Timer? _timer;
  StreamSubscription<void>? _changes;
  bool _disposed = false,
      _active = false,
      _foreground = true,
      _reading = false,
      _readAgain = false;
  bool _pending = false;
  int _epoch = 0;
  String? _signature;

  BackupStatusObservation({required this.coordinator, required this.changes}) {
    _events = StreamController<BackupStatus>.broadcast(
        onListen: _start, onCancel: _stop);
  }

  void _start() {
    if (_disposed) return;
    _active = true;
    _epoch++;
    _signature =
        null; // A recreated status subscription needs a fresh snapshot.
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _foreground = binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    _changes = changes.listen((_) => refreshNow());
    refreshNow();
  }

  void _stop() {
    if (!_active) return;
    _active = false;
    _epoch++;
    _timer?.cancel();
    _timer = null;
    unawaited(_changes?.cancel());
    _changes = null;
    WidgetsBinding.instance.removeObserver(this);
    // Do not cancel or clear a shared read. A new listener can join it safely.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    _timer = null;
    if (_foreground) refreshNow();
  }

  void refreshNow() => unawaited(_refresh());

  Future<void> _refresh() async {
    if (_disposed || !_active || !_foreground) return;
    _timer?.cancel();
    _timer = null;
    if (_reading) {
      _readAgain = true;
      return;
    }
    _reading = true;
    final epoch = _epoch;
    try {
      final status = await coordinator.readFresh();
      if (_disposed || !_active || !_foreground || epoch != _epoch) return;
      _pending = status.manualRequest?.pending == true;
      // Deduplicate every field used by either Settings or the root pill. This
      // is an observation fingerprint, never a second backup lifecycle state.
      final signature = jsonEncode([
        status.revision,
        status.uploadedRevision,
        status.dirtySince?.toIso8601String(),
        status.lastAttempt?.toIso8601String(),
        status.lastFailure?.toIso8601String(),
        status.lastSuccess?.toIso8601String(),
        status.failureMessage,
        status.manualRequest?.toJson(),
      ]);
      if (_signature != signature) {
        _signature = signature;
        _events.add(status);
      }
    } catch (_) {
      // Retain the last readable state without exposing storage exceptions.
    } finally {
      _reading = false;
      if (!_disposed && _active && _foreground) {
        if (_readAgain) {
          _readAgain = false;
          unawaited(_refresh());
        } else {
          _timer = Timer(
              _pending
                  ? const Duration(milliseconds: 750)
                  : const Duration(seconds: 15),
              () => unawaited(_refresh()));
        }
      }
    }
  }

  void dispose() {
    _disposed = true;
    _stop();
    unawaited(_events.close());
  }
}
