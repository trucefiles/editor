/// Why open edits must be kept now: the file closes, the app is hidden
/// (and may be ended), or the app exits.
enum SecureReason { close, hide, exit }
