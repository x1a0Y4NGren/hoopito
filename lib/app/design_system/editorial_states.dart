import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_masthead.dart';
import 'package:hoopito/app/design_system/editorial_primitives.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';

class EditorialSheet extends StatelessWidget {
  const EditorialSheet({
    required this.child,
    this.title,
    this.titleTrailing,
    this.actions = const [],
    this.padding = const EdgeInsets.all(HoopitoSpacing.page),
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? titleTrailing;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Material(
      color: editorial.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: editorial.ink, width: 2)),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    EditorialMasthead(
                      title: title!,
                      compact: true,
                      showRule: false,
                    ),
                    ?titleTrailing,
                  ],
                ),
                const SizedBox(height: 16),
              ],
              child,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditorialEmptyState extends StatelessWidget {
  const EditorialEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _EditorialState(
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    icon: icon,
    color: editorialThemeOf(context).mutedInk,
  );
}

class EditorialErrorState extends StatelessWidget {
  const EditorialErrorState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.error_outline,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _EditorialState(
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    icon: icon,
    color: editorialThemeOf(context).danger,
  );
}

class _EditorialState extends StatelessWidget {
  const _EditorialState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: editorial.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: editorial.mutedInk),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
