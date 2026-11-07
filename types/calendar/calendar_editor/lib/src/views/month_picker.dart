import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Asks the user for a month, from [first] to [last], starting on
/// [shown]'s, with [today]'s marked: the first day of the month they
/// pick, or `null` if they cancel.
///
/// Our own, as no trusted library picks only a month and Flutter's date
/// picker can't tell a year pick from a day tap; it looks and works like
/// Flutter's date picker: tap a month, then OK, and the year above the
/// months opens Flutter's own year list. Kept on its own behind this one
/// entry, so another picker can take its place.
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
    today: today,
    first: first,
    last: last,
  ),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.picked,
    required this.today,
    required this.first,
    required this.last,
  });

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
    final words = MaterialLocalizations.of(context);
    final theme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    final headerColor =
        theme.headerForegroundColor ?? defaults.headerForegroundColor;
    return Dialog(
      backgroundColor: theme.backgroundColor ?? defaults.backgroundColor,
      surfaceTintColor: theme.surfaceTintColor ?? defaults.surfaceTintColor,
      shape: theme.shape ?? defaults.shape,
      // As Flutter's date picker.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select month',
                    style: (theme.headerHelpStyle ?? defaults.headerHelpStyle)
                        ?.copyWith(color: headerColor),
                  ),
                  const SizedBox(height: 36),
                  // Short, as Flutter's day headline ("Wed, Nov 4").
                  Text(
                    DateFormat.yMMM(_localeOf(context)).format(_picked),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (theme.headerHeadlineStyle ??
                                defaults.headerHeadlineStyle)
                            ?.copyWith(color: headerColor),
                  ),
                ],
              ),
            ),
            Divider(height: 0, color: theme.dividerColor),
            _yearRow(context),
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
                        _picked = DateTime(year.year, _picked.month);
                        _pickingYear = false;
                      }),
                    )
                  : _months(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    style:
                        theme.cancelButtonStyle ?? defaults.cancelButtonStyle,
                    onPressed: () => Navigator.pop(context),
                    child: Text(words.cancelButtonLabel),
                  ),
                  TextButton(
                    style:
                        theme.confirmButtonStyle ?? defaults.confirmButtonStyle,
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

  /// The year shown, which opens the year list, and while months show,
  /// the previous and next year.
  Widget _yearRow(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final theme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    final color =
        theme.subHeaderForegroundColor ?? defaults.subHeaderForegroundColor;
    Widget step(int by, IconData icon, String tooltip) => IconButton(
      icon: Icon(icon),
      color: color,
      tooltip: tooltip,
      onPressed: _year + by < widget.first.year || _year + by > widget.last.year
          ? null
          : () => setState(() => _year += by),
    );
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        child: Row(
          children: [
            InkWell(
              onTap: () => setState(() => _pickingYear = !_pickingYear),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text(
                      words.formatYear(DateTime(_year)),
                      style:
                          (theme.toggleButtonTextStyle ??
                                  defaults.toggleButtonTextStyle)
                              ?.apply(color: color),
                    ),
                    Icon(
                      _pickingYear
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!_pickingYear) ...[
              step(-1, Icons.chevron_left, 'Previous year'),
              step(1, Icons.chevron_right, 'Next year'),
            ],
          ],
        ),
      ),
    );
  }

  /// The twelve months of the year shown, styled as Flutter's year list
  /// styles its years.
  Widget _months(BuildContext context) {
    final names = DateFormat.MMM(_localeOf(context));
    // As Flutter's year list sizes a year.
    final scale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 3).scale(14) /
        14;
    final theme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    T? resolve<T>(
      WidgetStateProperty<T>? Function(DatePickerThemeData theme) of,
      Set<WidgetState> states,
    ) => (of(theme) ?? of(defaults))?.resolve(states);

    Widget month(DateTime month) {
      final isToday =
          month.year == widget.today.year && month.month == widget.today.month;
      final states = {if (month == _picked) WidgetState.selected};
      final color = resolve<Color?>(
        (theme) =>
            isToday ? theme.todayForegroundColor : theme.yearForegroundColor,
        states,
      );
      final border = isToday
          ? (theme.todayBorder ?? defaults.todayBorder)?.copyWith(color: color)
          : null;
      final shape = resolve<OutlinedBorder?>(
        (theme) => theme.yearShape,
        states,
      )!;
      return Center(
        child: InkWell(
          customBorder: shape,
          overlayColor: WidgetStateProperty.resolveWith(
            (pressed) =>
                resolve<Color?>((theme) => theme.yearOverlayColor, pressed),
          ),
          onTap: () => setState(() => _picked = month),
          child: Ink(
            width: 72 * scale,
            height: 36 * scale,
            decoration: ShapeDecoration(
              color: resolve<Color?>(
                (theme) => isToday
                    ? theme.todayBackgroundColor
                    : theme.yearBackgroundColor,
                states,
              ),
              shape: shape.copyWith(side: border),
            ),
            child: Center(
              child: Text(
                names.format(month),
                style: (theme.yearStyle ?? defaults.yearStyle)?.apply(
                  color: color,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.7,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: List.generate(
        DateTime.monthsPerYear,
        (index) => month(DateTime(_year, index + 1)),
      ),
    );
  }
}

String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();
