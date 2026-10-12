import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';

class ScoreFlowChart extends StatelessWidget {
  const ScoreFlowChart({
    required this.entries,
    required this.redName,
    required this.blueName,
    super.key,
  });
  final List<ScoringFlowEntry> entries;
  final String redName;
  final String blueName;
  @override
  Widget build(BuildContext context) {
    final theme = editorialThemeOf(context);
    final last = entries.lastOrNull;
    return Semantics(
      label:
          '$redName ${last?.redScore ?? 0}, $blueName ${last?.blueScore ?? 0}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _ScoreFlowPainter(
                entries,
                theme.teamRed,
                theme.teamBlue,
                theme.rule,
              ),
            ),
          ),
          Wrap(
            spacing: 16,
            children: [
              Text(redName, style: TextStyle(color: theme.teamRed)),
              Text(blueName, style: TextStyle(color: theme.teamBlue)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreFlowPainter extends CustomPainter {
  _ScoreFlowPainter(this.entries, this.red, this.blue, this.rule);
  final List<ScoringFlowEntry> entries;
  final Color red, blue, rule;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 8 + (size.height - 16) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (entries.isEmpty) return;
    final maxScore = entries.fold<int>(
      1,
      (value, e) => math.max(value, math.max(e.redScore, e.blueScore)),
    );
    for (final isRed in [true, false]) {
      final path = Path()..moveTo(0, size.height - 8);
      for (var i = 0; i < entries.length; i++) {
        final score = isRed ? entries[i].redScore : entries[i].blueScore;
        final x = size.width * (i + 1) / entries.length;
        final y = size.height - 8 - (size.height - 16) * score / maxScore;
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = isRed ? red : blue
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreFlowPainter old) =>
      old.entries != entries ||
      old.red != red ||
      old.blue != blue ||
      old.rule != rule;
}
