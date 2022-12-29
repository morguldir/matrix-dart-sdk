/// Defines event status:
/// - removed
/// - error: (http request failed)
/// - sending: (http request started)
/// - sent: (http request successful)
/// - synced: (event came from sync loop)
/// - roomState
enum EventStatus {
  removed,
  error,
  sending,
  sent,
  synced,
  roomState,
}

/// returns `EventStatusEnum` value from `intValue`.
///
/// - -2 == removed;
/// - -1 == error;
/// -  0 == sending;
/// -  1 == sent;
/// -  2 == synced;
/// -  3 == roomState;
EventStatus eventStatusFromInt(int intValue) =>
    EventStatus.values[intValue + 2];

/// Takes two [EventStatus] values and returns the one with higher
/// (better in terms of message sending) status.
EventStatus latestEventStatus(EventStatus status1, EventStatus status2) =>
    status1.intValue > status2.intValue ? status1 : status2;

extension EventStatusExtension on EventStatus {
  /// returns int value of the event status.
  ///
  /// - -2 == removed;
  /// - -1 == error;
  /// -  0 == sending;
  /// -  1 == sent;
  /// -  2 == synced;
  /// -  3 == roomState;
  int get intValue => (index - 2);

  /// return `true` if the `EventStatus` equals `removed`.
  bool get isRemoved => this == EventStatus.removed;

  /// return `true` if the `EventStatus` equals `error`.
  bool get isError => this == EventStatus.error;

  /// return `true` if the `EventStatus` equals `sending`.
  bool get isSending => this == EventStatus.sending;

  /// return `true` if the `EventStatus` equals `roomState`.
  bool get isRoomState => this == EventStatus.roomState;

  /// returns `true` if the status is sent or later:
  /// [EventStatus.sent], [EventStatus.synced] or [EventStatus.roomState].
  bool get isSent => [
        EventStatus.sent,
        EventStatus.synced,
        EventStatus.roomState,
      ].contains(this);

  /// returns `true` if the status is `synced` or `roomState`:
  /// [EventStatus.synced] or [EventStatus.roomState].
  bool get isSynced => [
        EventStatus.synced,
        EventStatus.roomState,
      ].contains(this);
}
