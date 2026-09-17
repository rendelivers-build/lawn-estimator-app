/// Pure Dart unit-conversion and formatting helpers.
///
/// US customary units throughout the UI. No Flutter dependency, so these
/// can be unit-tested without a widget harness.
library;

import 'package:intl/intl.dart';

const double _sqFtPerSqYd = 9.0;
const double _sqFtPerAcre = 43560.0;

/// Converts square feet to square yards.
double sqftToSqyd(double sqft) => sqft / _sqFtPerSqYd;

/// Converts square feet to acres.
double sqftToAcres(double sqft) => sqft / _sqFtPerAcre;

/// Formats an area as e.g. "1,234 ft²" (rounded, thousands-separated).
String formatFt2(double ft2) =>
    '${NumberFormat.decimalPattern('en_US').format(ft2.round())} ft²';

/// Formats a date as e.g. "Sep 15, 2026" in US English.
String formatDate(DateTime date) =>
    DateFormat.yMMMd('en_US').format(date.toLocal());
