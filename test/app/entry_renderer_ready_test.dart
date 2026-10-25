import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/entry/entry_renderer_ready.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(entryRendererChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android waits for the host surface readiness reply', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await waitForEntryRenderer();
    expect(calls.single.method, 'waitUntilReady');
  });

  test('a disposed surface is reported as unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(waitForEntryRenderer(), throwsStateError);
  });

  test('iOS startup does not require an Android surface bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return false;
    });
    await waitForEntryRenderer();
    await waitForEntryPresentation();
    expect(calls, 0);
  });

  test('Android awaits removal of the native splash', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await waitForEntryPresentation();
    expect(calls.single.method, 'waitUntilPresented');
  });

  test('disposing the host cannot grant a presentation reply', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(waitForEntryPresentation(), throwsStateError);
  });
}
