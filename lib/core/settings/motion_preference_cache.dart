import 'package:flutter/services.dart';

enum MotionPreference { standard, reduced }

const entryMotionPreferenceArgumentPrefix = '--hoopito-entry-motion=';
const entryAnimationDisabledArgument = '--hoopito-entry-animation=disabled';
const _legacyEntryMotionPreferenceArgumentPrefix = '--hooptrace-entry-motion=';
const _legacyEntryAnimationDisabledArgument =
    '--hooptrace-entry-animation=disabled';

bool entryAnimationEnabledFromEntrypointArguments(Iterable<String> arguments) {
  return !arguments.contains(entryAnimationDisabledArgument) &&
      !arguments.contains(_legacyEntryAnimationDisabledArgument);
}

MotionPreference? motionPreferenceFromEntrypointArguments(
  Iterable<String> arguments,
) {
  for (final argument in arguments) {
    final prefix = argument.startsWith(entryMotionPreferenceArgumentPrefix)
        ? entryMotionPreferenceArgumentPrefix
        : argument.startsWith(_legacyEntryMotionPreferenceArgumentPrefix)
        ? _legacyEntryMotionPreferenceArgumentPrefix
        : null;
    if (prefix == null) continue;
    return switch (argument.substring(prefix.length)) {
      'standard' => MotionPreference.standard,
      'reduced' => MotionPreference.reduced,
      _ => null,
    };
  }
  return null;
}

/// A tiny platform cache used only to resolve entry motion before Drift has
/// finished its startup work. The database remains the source of truth.
abstract interface class MotionPreferenceCache {
  Future<MotionPreference?> read();

  Future<void> write(MotionPreference preference);
}

class PlatformMotionPreferenceCache implements MotionPreferenceCache {
  const PlatformMotionPreferenceCache();

  static const channelName =
      'io.github.x1a0y4ngren.hooptrace/entry_motion_preference';
  static const MethodChannel _channel = MethodChannel(channelName);

  @override
  Future<MotionPreference?> read() async {
    final value = await _channel.invokeMethod<String>('read');
    return switch (value) {
      'standard' => MotionPreference.standard,
      'reduced' => MotionPreference.reduced,
      _ => null,
    };
  }

  @override
  Future<void> write(MotionPreference preference) {
    return _channel.invokeMethod<void>('write', preference.name);
  }
}

class NullMotionPreferenceCache implements MotionPreferenceCache {
  const NullMotionPreferenceCache();

  @override
  Future<MotionPreference?> read() async => null;

  @override
  Future<void> write(MotionPreference preference) async {}
}
