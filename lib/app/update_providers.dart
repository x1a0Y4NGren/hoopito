import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/core/update/app_update.dart';

final updatePlatformProvider = Provider<UpdatePlatformGateway>(
  (ref) => DeviceUpdatePlatformGateway(),
);

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final updateControllerProvider = ChangeNotifierProvider<UpdateController>((
  ref,
) {
  return UpdateController(
    service: ref.watch(updateServiceProvider),
    platform: ref.watch(updatePlatformProvider),
    preferences: UpdatePreferencesRepository(ref.watch(appDatabaseProvider)),
  );
});

final updateNavigationObserverProvider = Provider<UpdateNavigationObserver>((
  ref,
) {
  final observer = UpdateNavigationObserver();
  ref.onDispose(observer.dispose);
  return observer;
});

/// Root and forwarded branch popups defer the auxiliary startup reminder.
/// The router's normal page stack remains independent.
class UpdateNavigationObserver extends NavigatorObserver with ChangeNotifier {
  final Set<Route<dynamic>> _popups = {};
  bool get hasPopup => _popups.isNotEmpty;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _popups.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popups.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popups.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _popups.remove(oldRoute);
    if (newRoute is PopupRoute) _popups.add(newRoute);
    notifyListeners();
  }
}
