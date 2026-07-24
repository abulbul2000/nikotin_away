import 'package:flutter/material.dart';

import '../core/app_texts.dart';

/// Free numeric pack-count entry — the user types the number directly
/// instead of picking from a preset dropdown. Internally maps the typed
/// value to the same legacy bucket strings ('1 paketten az', '1 paket', ...
/// '7+ paket') every risk/report consumer already expects
/// (BehaviorEngine._packRiskContributions, SurveyRecord.packsToLegacyCigarettes,
/// SurveyRecord.packCountEstimate), so nothing downstream needed to change —
/// only how the value is entered.
class PacksPerDaySection extends StatelessWidget {
  final String selectedPackOption;
  final ValueChanged<String> onPackOptionChanged;

  const PacksPerDaySection({
    super.key,
    required this.selectedPackOption,
    required this.onPackOptionChanged,
  });

  static String bucketForCount(double count) {
    if (count < 1) return '1 paketten az';
    if (count < 2) return '1 paket';
    if (count < 3) return '2 paket';
    if (count < 4) return '3 paket';
    if (count < 5) return '4 paket';
    if (count < 6) return '5 paket';
    if (count < 7) return '6 paket';
    return '7+ paket';
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: context.t('packsPerDayQuestion'),
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) {
          return;
        }
        onPackOptionChanged(bucketForCount(parsed));
      },
    );
  }
}
