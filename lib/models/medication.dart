/// A user-tracked medication and the times of day it should be taken
/// (e.g. ["08:00", "20:00"]) — the count of times is just `times.length`,
/// there's no separate "how many times a day" field to keep in sync.
class Medication {
  final String id;
  final String name;
  final List<String> times;
  final DateTime createdAt;

  const Medication({
    required this.id,
    required this.name,
    required this.times,
    required this.createdAt,
  });

  Medication copyWith({String? name, List<String>? times}) {
    return Medication(
      id: id,
      name: name ?? this.name,
      times: times ?? this.times,
      createdAt: createdAt,
    );
  }
}
