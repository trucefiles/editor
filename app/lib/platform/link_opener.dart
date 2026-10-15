import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final linkOpenerProvider = Provider<LinkOpener>((_) => const LinkOpener());

/// Opens web links in the system's browser.
class LinkOpener {
  const LinkOpener();

  /// `false` if no app could open [link].
  Future<bool> open(Uri link) async {
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } on Exception {
      // url_launcher reports a missing handler as an exception on some
      // platforms.
      return false;
    }
  }
}
