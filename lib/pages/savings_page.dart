import 'package:flutter/material.dart';

import '../models/savings_snapshot.dart';
import '../services/savings_service.dart';
import '../widgets/statistic_card.dart';

class SavingsPage extends StatefulWidget {
  final DateTime quitDate;
  final String packsPerDay;

  const SavingsPage({
    super.key,
    required this.quitDate,
    required this.packsPerDay,
  });

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final _service = SavingsService();
  late Future<SavingsSnapshot> _future;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SavingsSnapshot> _load() async {
    final price = await _service.getPackPrice();
    _priceController.text = price.toStringAsFixed(0);
    return _service.computeSavings(
      quitDate: widget.quitDate,
      packsPerDay: widget.packsPerDay,
    );
  }

  Future<void> _updatePrice() async {
    final value = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await _service.setPackPrice(value);
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasarruf')),
      body: FutureBuilder<SavingsSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snapshot.data!;
          final hours = s.lifeTimeRegained.inHours;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  StatisticCard(
                    label: 'Biriken para',
                    value: '${s.moneySaved.toStringAsFixed(0)} ₺',
                    icon: Icons.savings_outlined,
                  ),
                  StatisticCard(
                    label: 'İçilmeyen sigara',
                    value: '${s.cigarettesNotSmoked}',
                    icon: Icons.smoke_free,
                  ),
                  StatisticCard(
                    label: 'Kazanılan yaşam süresi',
                    value: '$hours saat',
                    icon: Icons.favorite_outline,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Paket fiyatı (₺)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(hintText: 'Örn: 80'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _updatePrice,
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
