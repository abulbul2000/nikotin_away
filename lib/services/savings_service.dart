import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_snapshot.dart';
import '../models/survey_record.dart';

/// Calculates money saved and cigarettes avoided since the quit date,
/// based on the user's reported pack consumption and a configurable
/// pack price. The price is stored locally so it can be edited later
/// from settings without touching the survey schema.
class SavingsService {
  static const _packPriceKey = 'pack_price_try';
  static const _cigarettesPerPack = 20;
  static const double _defaultPackPrice = 80.0; // TRY, editable by user

  Future<double> getPackPrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_packPriceKey) ?? _defaultPackPrice;
  }

  Future<void> setPackPrice(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_packPriceKey, price);
  }

  Future<SavingsSnapshot> computeSavings({
    required DateTime quitDate,
    required String packsPerDay,
  }) async {
    final packPrice = await getPackPrice();
    final packsPerDayValue = _packsToNumeric(packsPerDay);
    final daysSinceQuit = DateTime.now().difference(quitDate).inHours / 24;
    final safeDays = daysSinceQuit < 0 ? 0 : daysSinceQuit;

    final cigarettesNotSmoked =
        (safeDays * packsPerDayValue * _cigarettesPerPack).round();
    final moneySaved = safeDays * packsPerDayValue * packPrice;

    // Rough, commonly cited estimate: ~11 minutes of life regained per
    // cigarette not smoked. Presented as a motivational figure, not a
    // medical claim.
    final lifeTimeRegained = Duration(minutes: cigarettesNotSmoked * 11);

    return SavingsSnapshot(
      moneySaved: moneySaved,
      cigarettesNotSmoked: cigarettesNotSmoked,
      lifeTimeRegained: lifeTimeRegained,
    );
  }

  double _packsToNumeric(String packsPerDay) {
    switch (packsPerDay) {
      case '1 paketten az':
        return 0.5;
      case '1 paket':
        return 1;
      case '2 paket':
        return 2;
      case '3 paket':
        return 3;
      case '4 paket':
        return 4;
      case '5 paket':
        return 5;
      case '6 paket':
        return 6;
      case '7+ paket':
        return 7;
      case '3+ paket':
        return 4;
      default:
        return SurveyRecord.packLevel(packsPerDay).toDouble().clamp(0.5, 10);
    }
  }
}
