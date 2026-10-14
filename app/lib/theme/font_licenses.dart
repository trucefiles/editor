import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lists the bundled Inter font's license on the app's license page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/inter/LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], text);
  });
}
