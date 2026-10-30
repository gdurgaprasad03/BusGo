/// The four bus types the backend knows about.
enum BusType {
  acSeater('AC_SEATER', 'AC Seater'),
  nonAcSeater('NON_AC_SEATER', 'Non-AC Seater'),
  acSleeper('AC_SLEEPER', 'AC Sleeper'),
  nonAcSleeper('NON_AC_SLEEPER', 'Non-AC Sleeper');

  const BusType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get isSleeper => this == acSleeper || this == nonAcSleeper;
  bool get isAc => this == acSeater || this == acSleeper;

  static BusType fromApi(String value) =>
      BusType.values.firstWhere((t) => t.apiValue == value, orElse: () => BusType.nonAcSeater);
}
