import 'package:truce_core/truce_core.dart';

/// Whether the user may leave an open file or quit the app: once [keep]
/// kept its content, or when the user drops what can be kept nowhere
/// ([askToDiscard]), which [discard] then does.
Future<bool> mayGoOnceKept({
  required Future<bool> Function() keep,
  required Future<bool> Function() askToDiscard,
  required void Function() discard,
}) async {
  if (await keep()) return true;
  if (!await askToDiscard()) return false;
  discard();
  return true;
}

/// Whether an open file's content is kept as the user leaves or hides
/// the app: [secured] says so, or its folder can't be reached
/// ([reachSettled], once a running check is over), so it waits on this
/// device.
Future<bool> keptOrOutOfReach(
  Future<bool> secured,
  Future<Reach> Function() reachSettled,
) async => await secured || await reachSettled() == Reach.unreachable;
