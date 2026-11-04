import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

/// The month view's day names, all in the longest form whose every name
/// fits its column: the full name, else the short one, else its first
/// letter. Never broken mid-word.
Widget weekDayName(BuildContext context, DateTime date) => LayoutBuilder(
  builder: (context, constraints) {
    // kalender's own look for the names.
    final style = DefaultTextStyle.of(context).style
        .merge(KalenderTheme.of(context).weekDayHeaderStyle?.textStyle);
    final locale = Localizations.localeOf(context);
    List<String> forms(DateTime day) {
      final short = day.dayNameShortLocalized(locale);
      return [day.dayNameLocalized(locale), short, short.characters.first];
    }

    final week = [
      for (var day = 0; day < DateTime.daysPerWeek; day++)
        forms(DateTime(date.year, date.month, date.day + day)),
    ];
    final form = [0, 1].firstWhere(
      (form) => week.every(
        (names) => fitsInLine(
          names[form],
          width: constraints.maxWidth - 2 * _padding,
          style: style,
          context: context,
        ),
      ),
      orElse: () => 2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: _padding),
      child: Center(
        child: Text(
          forms(date)[form],
          style: style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  },
);

const _padding = 2.0;

/// The month view's header with [weekDayName].
const monthHeaderNames = MonthHeaderComponents(
  weekDayHeaderBuilder: weekDayName,
);
