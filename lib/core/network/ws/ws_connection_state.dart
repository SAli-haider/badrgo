/// Connection state for WebSocket transports.
enum WsConnectionState {
  /// WebSocket is disconnected and idle.
  disconnected,

  /// Connecting to WebSocket endpoint.
  connecting,

  /// WebSocket handshake completed and stream is active.
  connected,

  /// Connection dropped; waiting or attempting backoff reconnect.
  reconnecting,

  /// Connection encountered a fatal or unrecoverable error.
  error,
}
