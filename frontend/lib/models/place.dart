/// A place in the autocomplete list. [hasService] means at least one DEMO bus route starts or ends there.
/// Being listed does not mean buses run there.
class Place {
  final String name;
  final String state;
  final bool hasService;

  const Place({required this.name, required this.state, required this.hasService});

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        name: json['name'] as String,
        state: json['state'] as String,
        hasService: (json['hasService'] as bool?) ?? false,
      );
}

/// A state or union territory with how many places are listed and how many have demo bus service.
class StateInfo {
  final String name;
  final String type; // STATE or UNION_TERRITORY
  final int placeCount;
  final int servedPlaceCount;

  const StateInfo({
    required this.name,
    required this.type,
    required this.placeCount,
    required this.servedPlaceCount,
  });

  factory StateInfo.fromJson(Map<String, dynamic> json) => StateInfo(
        name: json['name'] as String,
        type: json['type'] as String,
        placeCount: (json['placeCount'] as num).toInt(),
        servedPlaceCount: (json['servedPlaceCount'] as num).toInt(),
      );
}
