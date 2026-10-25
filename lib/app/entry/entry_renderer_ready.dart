import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const entryRendererChannelName =
    'io.github.x1a0y4ngren.hooptrace/entry_renderer';
const _channel = MethodChannel(entryRendererChannelName);

/// Android creates its initial graphics surface synchronously on the merged
/// platform/UI thread. Begin the image's bounded wait after that work, while
/// the native splash still owns the screen. Other platforms need no bridge.
Future<void> waitForEntryRenderer() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final ready = await _channel.invokeMethod<bool>('waitUntilReady');
  if (ready != true) throw StateError('Entry surface unavailable');
}

/// Called only after Flutter submits its matching static first frame. Android
/// replies after removing the native splash (or first display before API 31).
Future<void> waitForEntryPresentation() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final presented = await _channel.invokeMethod<bool>('waitUntilPresented');
  if (presented != true) throw StateError('Entry presentation unavailable');
}
