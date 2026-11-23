import 'package:intl/intl.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ').map((str) => str.capitalize()).join(' ');
  }
}

extension DoubleExtension on double {
  String toFormattedString([int decimals = 1]) {
    return toStringAsFixed(decimals);
  }
}

extension DateTimeExtension on DateTime {
  String toDateString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  String toReadableDate() {
    return DateFormat('EEE, MMM d').format(this);
  }

  String toFullDate() {
    return DateFormat('MMMM d, yyyy').format(this);
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
