import 'package:flutter/material.dart';
import 'package:gyeol/core/theme/app_theme.dart';

class LayerNodeWidget extends StatelessWidget {
  final String name;
  final bool enabled;
  final int workerCount;
  final List<String> outputTypes;
  final int runningTasks;

  const LayerNodeWidget({
    super.key,
    required this.name,
    required this.enabled,
    required this.workerCount,
    required this.outputTypes,
    this.runningTasks = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        width: 240,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.textMuted,
            width: 2,
          ),
          boxShadow: runningTasks > 0
              ? [
                  BoxShadow(
                    color: AppColors.info.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (runningTasks > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$runningTasks',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.memory, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '$workerCount worker${workerCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (outputTypes.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: outputTypes
                      .take(3)
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
