import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/orientation_shell.dart';

void main() {
  test(
    'compact scoring requests landscape while large windows stay adaptive',
    () {
      expect(
        preferredOrientationsForWindow(
          HoopitoOrientationMode.landscapeRequired,
          shortestSide: 390,
        ),
        const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
      expect(
        preferredOrientationsForWindow(
          HoopitoOrientationMode.landscapeRequired,
          shortestSide: 700,
        ),
        DeviceOrientation.values,
      );
      expect(
        preferredOrientationsForWindow(
          HoopitoOrientationMode.landscapeRequired,
          shortestSide: 390,
          displayShortestSide: 800,
        ),
        DeviceOrientation.values,
      );
      expect(
        preferredOrientationsForWindow(
          HoopitoOrientationMode.portraitFriendly,
          shortestSide: 390,
        ),
        DeviceOrientation.values,
      );
    },
  );

  testWidgets('scoring shell opts into edge-to-edge without repeating it', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: OrientationShell(
          mode: HoopitoOrientationMode.landscapeRequired,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(
      calls.where(
        (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
      ),
      hasLength(1),
    );

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: OrientationShell(
          mode: HoopitoOrientationMode.landscapeRequired,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(
      calls.where(
        (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
      ),
      hasLength(1),
    );
  });
}
