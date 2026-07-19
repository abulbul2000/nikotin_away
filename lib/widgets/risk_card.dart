import 'package:flutter/material.dart';

class RiskCard extends StatelessWidget {
  final String riskLevel;
  final int riskScore;
  final VoidCallback? onTap;

  const RiskCard({
    super.key,
    required this.riskLevel,
    required this.riskScore,
    this.onTap,
  });

  Color get _levelColor {
    switch (riskLevel.toLowerCase()) {
      case 'kritik':
        return Colors.redAccent;
      case 'yüksek':
        return Colors.orangeAccent;
      case 'orta':
        return Colors.amber;
      case 'düşük':
        return Colors.lightGreen;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 48,
                decoration: BoxDecoration(
                  color: _levelColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk seviyesi: $riskLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Skor: $riskScore / 100',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
