/// [interval] for the UI, e.g. "10 s" or "5 min".
String intervalText(Duration interval) => interval.inSeconds < 60
    ? '${interval.inSeconds} s'
    : '${interval.inMinutes} min';
