import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/achievement.dart';
import '../models/reduction_progress.dart';
import '../services/achievement_service.dart';
import '../widgets/load_error_view.dart';

class AchievementsPage extends StatefulWidget {
  /// The figures every badge is measured against. Passed in rather than
  /// re-read here so the grid can never disagree with the card the user
  /// tapped to get here.
  final ReductionProgress progress;

  const AchievementsPage({super.key, required this.progress});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _service = AchievementService();
  late Future<List<Achievement>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Achievement>> _load() async {
    await _service.evaluateProgress(widget.progress);
    return _service.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('achievementsPageTitle'))),
      body: FutureBuilder<List<Achievement>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(
              onRetry: () => setState(() => _future = _load()),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final achievements = snapshot.data!;
          final unlockedCount = achievements.where((a) => a.unlocked).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context
                      .t('achievementsEarnedCount')
                      .replaceAll('{earned}', '$unlockedCount')
                      .replaceAll('{total}', '${achievements.length}'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    return _AchievementTile(
                      achievement: achievements[index],
                      progress: widget.progress,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final ReductionProgress progress;

  const _AchievementTile({required this.achievement, required this.progress});

  /// The badge's own yardstick, in the user's language. A tile that reads
  /// "30 days" next to one that reads "500 cigarettes" tells the user what
  /// each is asking of them; the old grid printed "N gün" on all of them
  /// because there was only ever one figure.
  String _thresholdText(BuildContext context) {
    switch (achievement.kind) {
      case AchievementKind.targetStreak:
        return '${achievement.threshold} ${context.t('dayUnit')}';
      case AchievementKind.cigarettesAvoided:
        return '${achievement.threshold} ${context.t('cigaretteUnit')}';
      case AchievementKind.intervalGain:
        return context
            .t('reductionIntervalGain')
            .replaceAll('{percent}', '${achievement.threshold}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !achievement.unlocked;
    final current = AchievementService.currentValueFor(
      achievement.kind,
      progress,
    );

    return Card(
      color: locked ? const Color(0xFF0F1B2A) : const Color(0xFF132238),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: locked ? 0.3 : 1,
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _thresholdText(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: locked ? Colors.white38 : AppTheme.brandPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (locked) ...[
              const SizedBox(height: 4),
              // How far along they are, so a locked badge reads as a target
              // rather than a closed door.
              Text(
                '$current / ${achievement.threshold}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Colors.white24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
