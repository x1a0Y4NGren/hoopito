import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';

class RouteLoading extends StatelessWidget {
  const RouteLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: l10n.routeLoading,
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class RouteMessage extends StatelessWidget {
  const RouteMessage({
    super.key,
    required this.title,
    required this.message,
    this.onHome,
    this.onReplay,
    this.onRetry,
    this.homeLabel,
    this.replayLabel,
  });

  final String title;
  final String message;
  final VoidCallback? onHome;
  final VoidCallback? onReplay;
  final VoidCallback? onRetry;
  final String? homeLabel;
  final String? replayLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (onReplay != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    key: const Key('route-message-replay'),
                    onPressed: onReplay,
                    child: Text(replayLabel ?? l10n.replayTitle),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    key: const Key('route-message-retry'),
                    onPressed: onRetry,
                    child: Text(l10n.retryAction),
                  ),
                ],
                if (onHome != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('route-message-home'),
                    onPressed: onHome,
                    child: Text(homeLabel ?? l10n.historyHomeTooltip),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
