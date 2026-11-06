import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';

final practicePreferencesProvider = Provider<PracticePreferences>(
  (ref) => PracticePreferences(ref.watch(appDatabaseProvider)),
);

/// Includes practice entry confirmation and exit dialogs, not only its pages.
final practiceFlowVisibleProvider = StateProvider<bool>((ref) => false);

/// The invitation gets first choice of startup popup; background checks continue.
final practiceInvitationBlockingProvider = StateProvider<bool>((ref) => false);

/// A failed optional preference write must not create a prompt loop this process.
final practiceInvitationHandledInMemoryProvider = StateProvider<bool>(
  (ref) => false,
);
