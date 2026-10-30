class User {
  final int id;
  final String fullName;
  final String email;

  /// Empty for accounts created with Google sign-in until the user adds a mobile number.
  final String phone;

  const User({required this.id, required this.fullName, required this.email, required this.phone});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: (json['phone'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'fullName': fullName, 'email': email, 'phone': phone};
}
