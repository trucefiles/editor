/// The days from [first] up to [end], each at midnight on this device's
/// clock; counted on day numbers, so a clock change never skips one.
List<DateTime> daysFrom(DateTime first, DateTime end) => List.generate(
  DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(first.year, first.month, first.day)).inDays,
  (index) => DateTime(first.year, first.month, first.day + index),
);
