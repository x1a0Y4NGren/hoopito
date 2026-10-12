import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_court_lines.dart';
import 'package:hoopito/app/design_system/editorial_primitives.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';

class EditorialScaffold extends StatelessWidget {
  const EditorialScaffold({
    required this.body,
    this.masthead,
    this.showCourtLines = false,
    this.maxContentWidth = 1120,
    this.safeArea = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  final Widget body;
  final Widget? masthead;
  final bool showCourtLines;
  final double maxContentWidth;
  final bool safeArea;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final pageInset = HoopitoSpacing.pageFor(viewportWidth);
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          key: const Key('editorial-page-padding'),
          padding: EdgeInsets.symmetric(
            horizontal: pageInset,
            vertical: HoopitoSpacing.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (masthead != null) ...[
                masthead!,
                SizedBox(height: HoopitoSpacing.sectionFor(viewportWidth)),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
    if (showCourtLines) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: EditorialCourtLinesPainter(
                color: editorial.rule.withValues(alpha: 0.24),
              ),
            ),
          ),
          content,
        ],
      );
    }
    if (safeArea) content = SafeArea(child: content);
    return Scaffold(
      backgroundColor: editorial.canvas,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
