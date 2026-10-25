import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/settings/motion_preference_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformMotionPreferenceCache.channelName);
  const cache = PlatformMotionPreferenceCache();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('missing platform plugin fails promptly instead of hanging startup', () {
    expect(
      cache.write(MotionPreference.standard),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test(
    'platform cache maps native values and writes stable enum names',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'read') return 'reduced';
            return null;
          });

      expect(await cache.read(), MotionPreference.reduced);
      await cache.write(MotionPreference.standard);

      expect(calls, hasLength(2));
      expect(calls.first.method, 'read');
      expect(calls.last.method, 'write');
      expect(calls.last.arguments, 'standard');
    },
  );

  test('unknown native values are treated as a missing cache', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'future-mode');

    expect(await cache.read(), isNull);
  });

  test('entrypoint arguments resolve only supported cached values', () {
    expect(
      motionPreferenceFromEntrypointArguments(const [
        '--unrelated=value',
        '--hoopito-entry-motion=standard',
      ]),
      MotionPreference.standard,
    );
    expect(
      motionPreferenceFromEntrypointArguments(const [
        '--hoopito-entry-motion=reduced',
      ]),
      MotionPreference.reduced,
    );
    expect(
      motionPreferenceFromEntrypointArguments(const [
        '--hoopito-entry-motion=future-mode',
      ]),
      isNull,
    );
    expect(motionPreferenceFromEntrypointArguments(const []), isNull);
  });

  test('entrypoint arguments can suppress replay after activity rebuild', () {
    expect(entryAnimationEnabledFromEntrypointArguments(const []), isTrue);
    expect(
      entryAnimationEnabledFromEntrypointArguments(const [
        '--hoopito-entry-animation=disabled',
      ]),
      isFalse,
    );
  });
}
