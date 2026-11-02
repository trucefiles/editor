/// Tells this device's time zone (an IANA name), asked anew each time so
/// a trip shows; `null` if it is unknown.
typedef DeviceZone = Future<String?> Function();
