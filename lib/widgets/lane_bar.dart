import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class LaneBar extends StatelessWidget {
  final List<LaneSegment> segments;
  final double height;
  final int? currentIndex;

  const LaneBar({
    super.key,
    required this.segments,
    this.height = 8,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: segments.asMap().entries.map((entry) {
            final index = entry.key;
            final segment = entry.value;
            final isDone = currentIndex != null && index < currentIndex!;
            final color = isDone
                ? context.colors.accent
                : (segment.type == SegmentType.work ? context.colors.work : context.colors.rest);
            return Expanded(
              flex: (segment.weight * 10).round().clamp(1, 1000),
              child: Container(color: color),
            );
          }).toList(),
        ),
      ),
    );
  }
}
