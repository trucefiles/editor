import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Asks the user for a month, from [first]'s to [last]'s, starting on
/// [shown]'s, with [today]'s marked: the first day of the month they
/// pick, or `null` if they cancel.
///
/// Our own, as no trusted library picks only a month and Flutter's date
/// picker can't tell a year pick from a day tap; it looks and works like
/// Flutter's date picker: tap a month, then OK; the year above the months
/// opens Flutter's own year list, and its arrows page the years. Kept on
/// its own behind this one entry, so another picker can take its place.
Future<DateTime?> pickMonth(
  BuildContext context, {
  required DateTime shown,
  required DateTime today,
  required DateTime first,
  required DateTime last,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _MonthPicker(
    picked: DateTime(shown.year, shown.month),
    today: DateTime(today.year, today.month),
    first: DateTime(first.year, first.month),
    last: DateTime(last.year, last.month),
  ),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.picked,
    required this.today,
    required this.first,
    required this.last,
  });

  /// Each the first day of its month.
  final DateTime picked;
  final DateTime today;
  final DateTime first;
  final DateTime last;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late DateTime _picked = widget.picked;

  /// The year whose months show.
  late int _year = _picked.year;
  bool _pickingYear = false;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(context);
    final words = MaterialLocalizations.of(context);
    return Dialog(
      backgroundColor: look.of((t) => t.backgroundColor),
      surfaceTintColor: look.of((t) => t.surfaceTintColor),
      shape: look.of((t) => t.shape),
      // As Flutter's date picker.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(look, picked: _picked),
            Divider(height: 0, color: look.of((t) => t.dividerColor)),
            _YearRow(
              look,
              year: _year,
              pickingYear: _pickingYear,
              onToggle: () => setState(() => _pickingYear = !_pickingYear),
              onStep: (by) => _hasYear(_year + by)
                  ? () => setState(() => _year += by)
                  : null,
            ),
            SizedBox(
              height: 280,
              child: _pickingYear
                  ? YearPicker(
                      firstDate: widget.first,
                      lastDate: widget.last,
                      currentDate: widget.today,
                      selectedDate: _picked,
                      onChanged: (year) => setState(() {
                        _year = year.year;
                        _picked = _within(DateTime(year.year, _picked.month));
                        _pickingYear = false;
                      }),
                    )
                  : _MonthGrid(
                      look,
                      year: _year,
                      picked: _picked,
                      today: widget.today,
                      canPick: (month) => _within(month) == month,
                      onPick: (month) => setState(() => _picked = month),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    style: look.of((t) => t.cancelButtonStyle),
                    onPressed: () => Navigator.pop(context),
                    child: Text(words.cancelButtonLabel),
                  ),
                  TextButton(
                    style: look.of((t) => t.confirmButtonStyle),
                    onPressed: () => Navigator.pop(context, _picked),
                    child: Text(words.okButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasYear(int year) =>
      year >= widget.first.year && year <= widget.last.year;

  /// [month], or the nearest one that can be picked.
  DateTime _within(DateTime month) => month.isBefore(widget.first)
      ? widget.first
      : month.isAfter(widget.last)
      ? widget.last
      : month;
}

/// How the picker looks: the date picker theme's values ([of]), the
/// locale's month names, and the text scale; taken once for its parts.
final class _Look {
  _Look.of(BuildContext context)
    : _own = DatePickerTheme.of(context),
      _defaults = DatePickerTheme.defaults(context),
      locale = Localizations.localeOf(context).toLanguageTag(),
      // As Flutter's year list sizes a year.
      scale =
          MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 3).scale(14) /
          14;

  final DatePickerThemeData _own;
  final DatePickerThemeData _defaults;
  final String locale;
  final double scale;

  /// The theme's [value]: the app's if set, else Flutter's default.
  T? of<T>(T? Function(DatePickerThemeData theme) value) =>
      value(_own) ?? value(_defaults);
}

/// "Select month" above the month picked, as Flutter's date picker heads
/// its days.
class _Header extends StatelessWidget {
  const _Header(this.look, {required this.picked});

  final _Look look;
  final DateTime picked;

  @override
  Widget build(BuildContext context) {
    final color = look.of((t) => t.headerForegroundColor);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select month',
            style: look.of((t) => t.headerHelpStyle)?.copyWith(color: color),
          ),
          const SizedBox(height: 36),
          // Short, as Flutter's day headline ("Wed, Nov 4").
          Text(
            DateFormat.yMMM(look.locale).format(picked),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: look
                .of((t) => t.headerHeadlineStyle)
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The [year] shown, which opens and closes the year list, and while the
/// months show, the previous and next year ([onStep] gives each one's
/// action, `null` where there is none).
class _YearRow extends StatelessWidget {
  const _YearRow(
    this.look, {
    required this.year,
    required this.pickingYear,
    required this.onToggle,
    required this.onStep,
  });

  final _Look look;
  final int year;
  final bool pickingYear;
  final VoidCallback onToggle;
  final VoidCallback? Function(int by) onStep;

  @override
  Widget build(BuildContext context) {
    final color = look.of((t) => t.subHeaderForegroundColor);
    Widget step(int by, IconData icon, String tooltip) => IconButton(
      icon: Icon(icon),
      color: color,
      tooltip: tooltip,
      onPressed: onStep(by),
    );
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        child: Row(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text(
                      MaterialLocalizations.of(context)
                          .formatYear(DateTime(year)),
                      style: look
                          .of((t) => t.toggleButtonTextStyle)
                          ?.apply(color: color),
                    ),
                    Icon(
                      pickingYear ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!pickingYear) ...[
              step(-1, Icons.chevron_left, 'Previous year'),
              step(1, Icons.chevron_right, 'Next year'),
            ],
          ],
        ),
      ),
    );
  }
}

/// The twelve months of [year], styled as Flutter's year list styles its
/// years: [picked] filled, [today]'s outlined, those not [canPick]
/// greyed.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid(
    this.look, {
    required this.year,
    required this.picked,
    required this.today,
    required this.canPick,
    required this.onPick,
  });

  final _Look look;
  final int year;
  final DateTime picked;
  final DateTime today;
  final bool Function(DateTime month) canPick;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    childAspectRatio: 1.7,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    children: List.generate(
      DateTime.monthsPerYear,
      (index) => _month(DateTime(year, index + 1)),
    ),
  );

  Widget _month(DateTime month) {
    final isToday = month == today;
    final enabled = canPick(month);
    final states = {
      if (month == picked) WidgetState.selected,
      if (!enabled) WidgetState.disabled,
    };
    final color =
        (isToday
                ? look.of((t) => t.todayForegroundColor)
                : look.of((t) => t.yearForegroundColor))
            ?.resolve(states);
    final shape = look.of((t) => t.yearShape)!.resolve(states)!;
    return Center(
      child: InkWell(
        customBorder: shape,
        overlayColor: look.of((t) => t.yearOverlayColor),
        onTap: enabled ? () => onPick(month) : null,
        child: Ink(
          width: 72 * look.scale,
          height: 36 * look.scale,
          decoration: ShapeDecoration(
            color:
                (isToday
                        ? look.of((t) => t.todayBackgroundColor)
                        : look.of((t) => t.yearBackgroundColor))
                    ?.resolve(states),
            shape: shape.copyWith(
              side: isToday
                  ? look.of((t) => t.todayBorder)?.copyWith(color: color)
                  : null,
            ),
          ),
          child: Center(
            child: Text(
              DateFormat.MMM(look.locale).format(month),
              style: look.of((t) => t.yearStyle)?.apply(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
