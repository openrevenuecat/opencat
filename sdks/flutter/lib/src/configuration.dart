/// Configuration for standalone mode (no server, on-device only).
class StandaloneConfiguration {
  final String appUserId;

  const StandaloneConfiguration({required this.appUserId});
}

/// Configuration for server mode (full features with OpenCat backend).
class ServerConfiguration {
  final String serverUrl;
  final String apiKey;
  final String appUserId;

  const ServerConfiguration({
    required this.serverUrl,
    required this.apiKey,
    required this.appUserId,
  });
}
