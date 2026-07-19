import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String description;
  final bool completed;
  final VoidCallback? onComplete;

  const TaskCard({
    super.key,
    required this.title,
    required this.description,
    this.completed = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      decoration:
                          completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onComplete,
              icon: Icon(
                completed ? Icons.check_circle : Icons.check_circle_outline,
                color: completed ? AppTheme.noSmokeGreen : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
