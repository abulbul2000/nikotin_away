import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/savings_snapshot.dart';
import '../services/savings_service.dart';
import '../widgets/load_error_view.dart';
import '../widgets/statistic_card.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

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
    if (mounted) {
      _priceController.text = price.toStringAsFixed(0);
    }
    return _service.computeSavings();
  }

  Future<void> _updatePrice() async {
    final value = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await _service.setPackPrice(value);
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('savingsPageTitle'))),
      body: FutureBuilder<SavingsSnapshot>(
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
                    label: context.t('savingsMoneySaved'),
                    value: '${s.moneySaved.toStringAsFixed(0)} ₺',
                    icon: Icons.savings_outlined,
                  ),
                  StatisticCard(
                    label: context.t('savingsCigarettesNotSmoked'),
                    value: '${s.cigarettesNotSmoked}',
                    icon: Icons.smoke_free,
                  ),
                  StatisticCard(
                    label: context.t('savingsLifeTimeRegained'),
                    value: context
                        .t('savingsHoursUnit')
                        .replaceAll('{hours}', '$hours'),
                    icon: Icons.favorite_outline,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                context.t('savingsPackPriceLabel'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                      decoration: InputDecoration(
                        hintText: context.t('savingsPackPriceHint'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _updatePrice,
                    child: Text(context.t('savingsSaveButton')),
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
