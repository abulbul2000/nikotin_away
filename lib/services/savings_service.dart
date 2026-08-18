import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_snapshot.dart';
import 'storage_service.dart';

/// Calculates money saved and cigarettes avoided, based on the user's
/// actual reduction progress and a configurable pack price. The price is
/// stored locally so it can be edited later from settings without
/// touching the survey schema.
class SavingsService {
  static const _packPriceKey = 'pack_price_try';
  static const _cigarettesPerPack = 20;
  static const double _defaultPackPrice = 80.0; // TRY, editable by user

  final StorageService _storageService;

  SavingsService({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  Future<double> getPackPrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_packPriceKey) ?? _defaultPackPrice;
  }

  Future<void> setPackPrice(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_packPriceKey, price);
  }

  /// Was `(now - quitDate) * packsPerDay` — the same "assumes zero
  /// cigarettes smoked since day one" bug already found and fixed twice
  /// elsewhere this session (home_page.dart's reduction streak,
  /// ReportEngine's estimatedAvertedCigarettes): this product is gradual
  /// reduction, not abstinence, so a user who cut down from 20/day to
  /// 15/day still saw savings computed as if they'd smoked nothing at all
  /// since quitDate. Now reuses StorageService.loadReductionProgress's
  /// already-correct, evidence-based cigarettesAvoided (summed only over
  /// days with a real logged count or answered task, day by day against
  /// that day's actual target) instead of reinventing the same figure
  /// from quitDate/packsPerDay alone.
  Future<SavingsSnapshot> computeSavings() async {
    final packPrice = await getPackPrice();
    final progress = await _storageService.loadReductionProgress();
    final cigarettesNotSmoked = progress.cigarettesAvoided;

    final moneySaved = (cigarettesNotSmoked / _cigarettesPerPack) * packPrice;

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
}
