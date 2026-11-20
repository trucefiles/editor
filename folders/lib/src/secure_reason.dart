/// Why open edits must be kept now: the file closes, the app is hidden
/// (and may be ended), or the app exits.
enum SecureReason { close, hide, exit }

/// How an ask to keep open edits went: [kept] for its reason; else
/// whether this device holds them as they are now ([onDevice]), so they
/// go into the file at the next start.
typedef SecureResult = ({bool kept, bool onDevice});
