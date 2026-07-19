import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';

class AchievementsPage extends StatefulWidget {
  final int smokeFreeDays;

  const AchievementsPage({super.key, required this.smokeFreeDays});

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
    await _service.evaluateProgress(widget.smokeFreeDays);
    return _service.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rozetler')),
      body: FutureBuilder<List<Achievement>>(
        future: _future,
        builder: (context, snapshot) {
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
                  '$unlockedCount / ${achievements.length} rozet kazanıldı',
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
                    final a = achievements[index];
                    return _AchievementTile(achievement: a);
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

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final locked = !achievement.unlocked;
    return Card(
      color: locked ? const Color(0xFF0F1B2A) : const Color(0xFF132238),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: locked ? 0.3 : 1,
              child: Text(achievement.icon, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 10),
            Text(
              '${achievement.thresholdDays} gün',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: locked ? Colors.white38 : AppTheme.noSmokeGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (locked)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.lock_outline, size: 14, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }
}
