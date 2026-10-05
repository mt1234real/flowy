import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/widgets/backup_progress_curtain.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';
import 'package:pfm_app/widgets/manual_backup_action.dart';

void main() {
  late StreamController<BackupStatus> statuses;
  late ManualBackupRequest request;
  setUp(() {
    statuses = StreamController<BackupStatus>.broadcast();
    request = ManualBackupRequest(
        id: 'request',
        phase: ManualBackupPhase.queued,
        queuedAt: DateTime(2026, 10, 3));
    backupNavigatorKey = GlobalKey<NavigatorState>();
  });
  tearDown(() async {
    await statuses.close();
  });

  Future<void> mount(WidgetTester tester,
      Future<ManualBackupRequest> Function() enqueue) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          backupStatusProvider.overrideWith((ref) => statuses.stream),
          manualBackupEnqueueProvider.overrideWithValue(enqueue),
        ],
        child: MaterialApp(
            navigatorKey: backupNavigatorKey,
            home: BackupProgressHost(
                child: Scaffold(
                    body: Column(children: [
              ManualBackupAction(
                  enabled: true,
                  builder: (pending, action) => ElevatedButton(
                      onPressed: action, child: const Text('Manual'))),
              Builder(
                  builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const Scaffold(body: Text('Other page')))),
                      child: const Text('Leave settings'))),
              const BackupStatusDetails(),
            ]))))));
    statuses.add(const BackupStatus());
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    // Expire the existing feedback banner; no timing assertion depends on it.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('tapManualBackup_returnsAfterEnqueue_withoutWaitingForUpload',
      (tester) async {
    final upload = Completer<void>(); // Upload is independently pending.
    await mount(tester, () async {
      statuses.add(BackupStatus(manualRequest: request));
      return request;
    });
    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(upload.isCompleted, isFalse);
    expect(find.text('Đã đưa yêu cầu sao lưu vào hàng đợi.'), findsNothing);
    await tester.tap(find.text('Leave settings'));
    await tester.pumpAndSettle();
    expect(find.text('Other page'), findsOneWidget);
    expect(upload.isCompleted, isFalse);
    upload.complete();
    await finish(tester);
  });
  testWidgets('manualBackup_doesNotOpenBlockingCurtain_orShowFalseSuccess',
      (tester) async {
    await mount(tester, () async => request);
    await tester.tap(find.text('Manual'));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ManualBackupAction)));
    expect(container.read(backupOperationProvider), isNull);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Vui lòng giữ ứng dụng mở.'), findsNothing);
    expect(find.textContaining('Đã sao lưu lên Google Drive'), findsNothing);
    expect(find.text('Đã đưa yêu cầu sao lưu vào hàng đợi.'), findsNothing);
    await finish(tester);
  });
  testWidgets('repeatTap_isDisabledDuringEnqueue_andQueuedRequest',
      (tester) async {
    var calls = 0;
    final registration = Completer<ManualBackupRequest>();
    await mount(tester, () {
      calls++;
      return registration.future;
    });
    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await tester.tap(find.text('Manual'));
    expect(calls, 1);
    statuses.add(BackupStatus(manualRequest: request));
    registration.complete(request);
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await finish(tester);
  });
  testWidgets('manualRequest_statusSurvivesForegroundProviderRecreation',
      (tester) async {
    await mount(tester, () async => request);
    statuses.add(BackupStatus(manualRequest: request));
    await tester.pump();
    expect(find.textContaining('đang chờ chạy'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await mount(tester, () async => request);
    statuses.add(BackupStatus(manualRequest: request));
    await tester.pump();
    expect(find.textContaining('đang chờ chạy'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await finish(tester);
  });
  testWidgets('enqueueFailure_usesSafeFeedback_andAllowsRetry', (tester) async {
    await mount(
        tester, () async => throw StateError('token raw platform detail'));
    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(find.textContaining('Chưa đưa được yêu cầu'), findsOneWidget);
    expect(find.textContaining('token raw'), findsNothing);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    await finish(tester);
  });
  testWidgets('backgroundCompletion_showsPersistedSuccess_andReenablesButton',
      (tester) async {
    await mount(tester, () async => request);
    statuses.add(BackupStatus(
        manualRequest: ManualBackupRequest(
            id: request.id,
            phase: ManualBackupPhase.running,
            queuedAt: request.queuedAt)));
    await tester.pump();
    expect(find.textContaining('đang chạy trong nền'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    statuses.add(BackupStatus(
        manualRequest: ManualBackupRequest(
            id: request.id,
            phase: ManualBackupPhase.success,
            queuedAt: request.queuedAt,
            finishedAt: DateTime.now())));
    await tester.pump();
    expect(find.textContaining('đã thành công'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    await finish(tester);
  });
}
