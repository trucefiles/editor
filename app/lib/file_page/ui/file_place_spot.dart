/// Where a file's page shows the file's location and name.
enum FilePlaceSpot { aboveText, menu }

/// Where the page shows the place: above the text if the device setting
/// says so ([aboveText]), else in the file's menu; a [readOnly] page has
/// no menu, so there it stays above the text.
FilePlaceSpot filePlaceSpot({
  required bool aboveText,
  required bool readOnly,
}) => aboveText || readOnly ? FilePlaceSpot.aboveText : FilePlaceSpot.menu;
