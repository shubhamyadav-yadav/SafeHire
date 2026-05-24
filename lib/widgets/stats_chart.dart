import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StatsChart extends StatelessWidget {
  final int safe;
  final int threats;

  const StatsChart({required this.safe, required this.threats, Key? key})
      : super(key: key);

  static const Color _green   = Color(0xFF00E676);
  static const Color _red     = Color(0xFFFF3B5C);
  static const Color _textSub = Color(0xFF6B7A8D);

  @override
  Widget build(BuildContext context) {
    final total = safe + threats;

    // Empty state
    if (total == 0) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, color: _textSub, size: 36),
              const SizedBox(height: 10),
              Text(
                "No scans yet",
                style: TextStyle(color: _textSub, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                "Run an analysis to see stats here",
                style: TextStyle(color: _textSub.withOpacity(0.6), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: Row(
        children: [
          // Pie chart
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                startDegreeOffset: -90,
                sections: [
                  PieChartSectionData(
                    value: safe.toDouble(),
                    color: _green,
                    radius: 28,
                    title: '',
                    badgeWidget: safe > 0
                        ? Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF00E676), size: 10),
                    )
                        : null,
                    badgePositionPercentageOffset: 1.3,
                  ),
                  PieChartSectionData(
                    value: threats.toDouble(),
                    color: _red,
                    radius: 28,
                    title: '',
                    badgeWidget: threats > 0
                        ? Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded, color: Color(0xFFFF3B5C), size: 10),
                    )
                        : null,
                    badgePositionPercentageOffset: 1.3,
                  ),
                ],
              ),
            ),
          ),

          // Legend + numbers
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendRow(_green, "Safe", safe, total),
                const SizedBox(height: 14),
                _legendRow(_red, "Threats", threats, total),
                const SizedBox(height: 14),
                Divider(color: const Color(0xFF1E2D3D), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text("Total  ", style: TextStyle(color: _textSub, fontSize: 11)),
                    Text(
                      "$total",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int value, int total) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(color: _textSub, fontSize: 12)),
        ),
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "($pct%)",
          style: TextStyle(color: _textSub, fontSize: 10),
        ),
      ],
    );
  }
}