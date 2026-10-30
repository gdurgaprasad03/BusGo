/// Traveller details the user saved for reuse.
class SavedPassenger {
  final int id;
  final String name;
  final int age;
  final String gender; // MALE, FEMALE or OTHER

  const SavedPassenger({required this.id, required this.name, required this.age, required this.gender});

  factory SavedPassenger.fromJson(Map<String, dynamic> json) => SavedPassenger(
        id: json['id'] as int,
        name: json['name'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
      );

  String get genderLabel => '${gender[0]}${gender.substring(1).toLowerCase()}';
}
