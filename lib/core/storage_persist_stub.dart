/// No-op on non-web platforms — persistent storage is already durable
/// there, so there's nothing to request.
Future<void> requestPersistentStorage() async {}
