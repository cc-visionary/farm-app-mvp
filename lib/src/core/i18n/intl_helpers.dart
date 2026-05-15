import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats a PHP amount with ₱ symbol and the current locale's separator.
/// Pass via [BuildContext] so we read the current locale; no decimals in v1.
String formatCurrencyPhp(BuildContext context, num amount) {
  final locale = Localizations.localeOf(context).toString();
  final f = NumberFormat.currency(locale: locale, symbol: '₱', decimalDigits: 0);
  return f.format(amount);
}

/// Formats a date in medium form ("May 15, 2026" / "Mayo 15, 2026").
String formatMediumDate(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(dt);
}

/// Formats a time in jm form ("4:30 PM" / "4:30 PM" — `intl` uses
/// the same skeleton in fil; localized AM/PM may differ slightly).
String formatJm(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.jm(locale).format(dt);
}

/// Decimal number formatter respecting locale separators.
String formatDecimal(BuildContext context, num value) {
  final locale = Localizations.localeOf(context).toString();
  return NumberFormat.decimalPattern(locale).format(value);
}
