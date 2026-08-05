// lib/models/chat/call_invite.dart
import 'call_status.dart';

class CallInvite {
  final String id;
  final String channelName;
  final String callerId;
  final String calleeId;
  final CallType callType;
  final CallStatus status;
  final String? callerName;
  final String? callerAvatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CallInvite({
    required this.id,
    required this.channelName,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.status,
    this.callerName,
    this.callerAvatar,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVideo => callType == CallType.video;
  bool get isAudio => callType == CallType.audio;
  bool get isRinging => status == CallStatus.ringing;

  factory CallInvite.fromJson(Map<String, dynamic> json) {
    return CallInvite(
      id: json['id'] as String,
      // Compatible avec la vraie colonne "channel"
      channelName: (json['channel'] ?? json['channel_name'] ?? '') as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      callType: CallType.fromString(json['call_type'] as String? ?? 'audio'),
      status: CallStatus.fromString(json['status'] as String? ?? 'ringing'),
      callerName: json['caller_name'] as String?,
      callerAvatar: json['caller_avatar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['created_at']) as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel': channelName,
        'caller_id': callerId,
        'callee_id': calleeId,
        'call_type': callType.name,
        'status': status.name,
        'caller_name': callerName,
        'caller_avatar': callerAvatar,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  CallInvite copyWith({
    String? id,
    String? channelName,
    String? callerId,
    String? calleeId,
    CallType? callType,
    CallStatus? status,
    String? callerName,
    String? callerAvatar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CallInvite(
      id: id ?? this.id,
      channelName: channelName ?? this.channelName,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CallInvite($id, $callType, $status, $callerId->$calleeId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallInvite &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
