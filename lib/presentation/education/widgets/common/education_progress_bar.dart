// lib/presentation/education/widgets/common/education_progress_bar.dart
import 'package:flutter/material.dart';

class EducationProgressBar extends StatelessWidget {
  final double progress; // 0.0 à 1.0
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final bool showLabel;
  final String? labelText;

  const EducationProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.backgroundColor,
    this.progressColor,
    this.showLabel = false,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final bgColor = backgroundColor ?? const Color(0xFFF0F7FF);
    final pColor = progressColor ?? const Color(0xFF2D6CDF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labelText ?? 'Progression',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7386A8),
                ),
              ),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D6CDF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor: bgColor,
            color: pColor,
            minHeight: height,
          ),
        ),
      ],
    );
  }
}
