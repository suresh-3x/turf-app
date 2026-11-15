import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('EEE, d MMM');
final _dayLong = DateFormat('EEEE, d MMMM y');
final _time = DateFormat('h:mm a');

String formatPrice(double amount) => amount == 0 ? 'Free' : _currency.format(amount);
String formatDay(DateTime date) => _day.format(date);
String formatDayLong(DateTime date) => _dayLong.format(date);
String formatTime(DateTime date) => _time.format(date);
String formatTimeRange(DateTime start, DateTime end) => '${formatTime(start)} – ${formatTime(end)}';
String formatSlot(DateTime start, DateTime end) =>
    '${formatDay(start)} · ${formatTimeRange(start, end)}';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  if (m == 0) return h == 1 ? '1 hr' : '$h hrs';
  return '$h hr $m min';
}

/// "just now", "5 min ago", "3 h ago", otherwise the date.
String formatRelative(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDay(time);
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
