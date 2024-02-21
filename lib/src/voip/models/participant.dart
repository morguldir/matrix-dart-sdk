import 'package:matrix/matrix.dart';

class Participant {
  final String userId;
  final String deviceId;

  Participant({required this.userId, required this.deviceId});

  String get id => '$userId:$deviceId';

  @override
  String toString() {
    return id;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          userId == other.userId &&
          deviceId == other.deviceId;

  @override
  int get hashCode => userId.hashCode ^ deviceId.hashCode;

  factory Participant.fromId(String id) {
    final int lastIndex = id.lastIndexOf(':');
    final userId = id.substring(0, lastIndex);
    final deviceId = id.substring(lastIndex + 1);
    if (!userId.isValidMatrixId) {
      throw FormatException('[Participant] $userId is not a valid matrixId');
    }
    return Participant(
      userId: userId,
      deviceId: deviceId,
    );
  }

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        userId: json['userId'] as String,
        deviceId: json['deviceId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deviceId': deviceId,
      };
}