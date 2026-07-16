import '../models/survey_record.dart';

class HomeSeed {
  final String name;
  final String packsPerDay;
  final int riskScore;
  final String riskLevel;

  const HomeSeed({
    required this.name,
    required this.packsPerDay,
    required this.riskScore,
    required this.riskLevel,
  });
}

class HomeSeedResolver {
  static HomeSeed fromRecords(List<SurveyRecord> records) {
    var name = 'User';
    var packsPerDay = '1 paketten az';
    var riskScore = 40;
    var riskLevel = 'ORTA';

    for (final record in records.reversed) {
      if (record.name.toString().trim().isNotEmpty) {
        name = record.name.toString().trim();
        break;
      }
    }

    for (final record in records.reversed) {
      if (record.type == 'breath_test' ||
          record.type == 'weekly' ||
          record.type == 'initial') {
        packsPerDay = record.packsPerDay;
        riskScore = record.riskScore;
        riskLevel = record.riskLevel;
        break;
      }
    }

    return HomeSeed(
      name: name,
      packsPerDay: packsPerDay,
      riskScore: riskScore,
      riskLevel: riskLevel,
    );
  }
}
