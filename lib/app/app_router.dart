import 'package:go_router/go_router.dart';
import 'package:hoopito/app/provider_router.dart';

export 'provider_router.dart' show appRouterProvider, buildProviderAppRouter;

/// Compatibility entry point retained for callers that used the pre-1.0
/// router factory. Production uses [buildProviderAppRouter], whose routes read
/// all dependencies from the Riverpod composition root.
@Deprecated('Use buildProviderAppRouter or appRouterProvider.')
GoRouter buildAppRouter([
  Object? legacyMatchSessions,
  Object? legacyPlayerRepository,
  Object? legacyRuleTemplates,
  Object? legacyExports,
  Object? legacyAutomaticBackup,
]) {
  return buildProviderAppRouter();
}
