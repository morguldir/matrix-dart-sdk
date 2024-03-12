import 'package:matrix/matrix.dart';

/// https://github.com/matrix-org/matrix-doc/pull/2746
/// version 1
const String voipProtoVersion = '1';

class CallTimeouts {
  /// The default life time for call events, in millisecond.
  static const defaultCallEventLifetime = Duration(seconds: 10);

  /// The length of time a call can be ringing for.
  static const callInviteLifetime = Duration(seconds: 60);

  /// The delay for ice gathering.
  static const iceGatheringDelay = Duration(milliseconds: 200);

  /// Delay before createOffer.
  static const delayBeforeOffer = Duration(milliseconds: 100);

  /// How often to update the expiresTs
  static const updateExpireTsTimerDuration = Duration(minutes: 2);

  /// the expiresTs bump
  static const expireTsBumpDuration = Duration(minutes: 6);

  /// Update the active speaker value
  static const activeSpeakerInterval = Duration(seconds: 5);

  // source: element call?
  /// A delay after a member leaves before we create and publish a new key, because people
  /// tend to leave calls at the same time
  static const makeKeyDelay = Duration(milliseconds: 3000);

  /// The delay between creating and sending a new key and starting to encrypt with it. This gives others
  /// a chance to receive the new key to minimise the chance they don't get media they can't decrypt.
  /// The total time between a member leaving and the call switching to new keys is therefore
  /// makeKeyDelay + useKeyDelay
  static const useKeyDelay = Duration(milliseconds: 5000);
}

class CallConstants {
  static const callEndedEventTypes = {
    EventTypes.CallAnswer,
    EventTypes.CallHangup,
    EventTypes.CallReject,
    EventTypes.CallReplaces,
  };
  static const ommitWhenCallEndedTypes = {
    EventTypes.CallInvite,
    EventTypes.CallCandidates,
    EventTypes.CallNegotiate,
    EventTypes.CallSDPStreamMetadataChanged,
    EventTypes.CallSDPStreamMetadataChangedPrefix,
  };
}
