import 'package:intl/intl.dart';

/// Small helpers that turn raw values into text for the UI.
class Fmt {
  Fmt._();

  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _date = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, hh:mm a');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static final DateFormat _dmy = DateFormat('d MMM yyyy');
  static final DateFormat _weekday = DateFormat('EEEE');

  /// "24 Aug 2025"
  static String dmy(DateTime d) => _dmy.format(d);

  /// "Sunday"
  static String weekday(DateTime d) => _weekday.format(d);

  static String time(DateTime d) => _time.format(d);
  static String date(DateTime d) => _date.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String apiDate(DateTime d) => _apiDate.format(d);
  static String money(num amount) => _money.format(amount);

  /// 270 -> "4h 30m"
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
