// lib/presentation/chat/call/providers/call_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/chat/call_invite.dart';
import '../../../../models/chat/call_status.dart';
import '../../../../services/chat/call_service.dart';
import '../../../../services/chat/call_signaling_service.dart';

class CallState {
  final CallStatus status;
  final CallType type;
  final String? inviteId;
  final String? channelName;
  final String? remoteUserId;
  final String? remoteName;
  final String? remoteAvatar;
  final int? remoteUid;
  final bool muted;
  final bool videoOff;
  final bool speakerOn;
  final bool isFrontCam;
  final bool isCaller;
  final Duration duration;
  final String? error;

  const CallState({
    this.status = CallStatus.idle,
    this.type = CallType.audio,
    this.inviteId,
    this.channelName,
    this.remoteUserId,
    this.remoteName,
    this.remoteAvatar,
    this.remoteUid,
    this.muted = false,
    this.videoOff = false,
    this.speakerOn = true,
    this.isFrontCam = true,
    this.isCaller = true,
    this.duration = Duration.zero,
    this.error,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? type,
    String? inviteId,
    String? channelName,
    String? remoteUserId,
    String? remoteName,
    String? remoteAvatar,
    int? remoteUid,
    bool? muted,
    bool? videoOff,
    bool? speakerOn,
    bool? isFrontCam,
    bool? isCaller,
    Duration? duration,
    String? error,
    bool clearError = false,
  }) {
    return CallState(
      status: status ?? this.status,
      type: type ?? this.type,
      inviteId: inviteId ?? this.inviteId,
      channelName: channelName ?? this.channelName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteName: remoteName ?? this.remoteName,
      remoteAvatar: remoteAvatar ?? this.remoteAvatar,
      remoteUid: remoteUid ?? this.remoteUid,
      muted: muted ?? this.muted,
      videoOff: videoOff ?? this.videoOff,
      speakerOn: speakerOn ?? this.speakerOn,
      isFrontCam: isFrontCam ?? this.isFrontCam,
      isCaller: isCaller ?? this.isCaller,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isVideo => type == CallType.video;
  bool get isActive =>
      status == CallStatus.ringing ||
      status == CallStatus.accepted ||
      status == CallStatus.ongoing;
}

class CallNotifier extends StateNotifier<CallState> {
  final _media = CallMediaService();
  final _signal = CallSignalingService();

  Timer? _timer;
  Timer? _ringTimeout;
  StreamSubscription? _statusSub;

  CallNotifier() : super(const CallState());

  int _uidFrom(String userId) {
    var hash = 0x811c9dc5;
    for (final c in userId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }

  /// Caller démarre
  Future<void> start({
    required String myUserId,
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    required CallType type,
  }) async {
    try {
      state = state.copyWith(
        status: CallStatus.ringing,
        type: type,
        isCaller: true,
        remoteUserId: calleeId,
        remoteName: calleeName,
        remoteAvatar: calleeAvatar,
        clearError: true,
      );

      final invite = await _signal.startCall(calleeId: calleeId, type: type);

      if (invite.status == CallStatus.busy) {
        state = state.copyWith(status: CallStatus.busy, error: 'Occupé');
        return;
      }

      state = state.copyWith(
        inviteId: invite.id,
        channelName: invite.channelName,
      );

      // Timeout 45s
      _ringTimeout?.cancel();
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (state.status == CallStatus.ringing && state.inviteId != null) {
          await _signal.markMissed(state.inviteId!);
          await hangUp();
        }
      });

      // Écoute accept / reject
      _statusSub?.cancel();
      _statusSub = _signal.watchInviteStatus(invite.id).listen((s) async {
        if (s == CallStatus.accepted || s == CallStatus.ongoing) {
          _ringTimeout?.cancel();
          await _joinAgora(myUserId);
        } else if (s.isFinished) {
          await hangUp(skipSignal: true);
        }
      });
    } catch (e) {
      debugPrint('❌ start call: $e');
      state = state.copyWith(status: CallStatus.failed, error: '$e');
    }
  }

  /// Callee accepte
  Future<void> acceptIncoming({
    required CallInvite invite,
    required String myUserId,
    String? callerName,
    String? callerAvatar,
  }) async {
    try {
      state = state.copyWith(
        status: CallStatus.accepted,
        type: invite.callType,
        isCaller: false,
        inviteId: invite.id,
        channelName: invite.channelName,
        remoteUserId: invite.callerId,
        remoteName: callerName ?? invite.callerName,
        remoteAvatar: callerAvatar ?? invite.callerAvatar,
        clearError: true,
      );

      await _signal.accept(invite.id);
      await _joinAgora(myUserId);
    } catch (e) {
      state = state.copyWith(status: CallStatus.failed, error: '$e');
    }
  }

  Future<void> rejectIncoming(String inviteId) async {
    await _signal.reject(inviteId);
    state = const CallState();
  }

  Future<void> _joinAgora(String myUserId) async {
    final channel = state.channelName;
    final inviteId = state.inviteId;
    if (channel == null) return;

    final uid = _uidFrom(myUserId);

    await _media.join(
      channel: channel,
      type: state.type,
      uid: uid,
      onUserJoined: (remoteUid) async {
        state = state.copyWith(
          remoteUid: remoteUid,
          status: CallStatus.ongoing,
        );
        if (inviteId != null) {
          await _signal.markOngoing(inviteId);
        }
        _startTimer();
      },
      onUserLeft: (_) async {
        await hangUp();
      },
      onError: (err) {
        state = state.copyWith(error: err);
      },
    );

    // Si on est déjà accepted, passer ongoing côté UI
    if (state.status == CallStatus.accepted) {
      state = state.copyWith(status: CallStatus.ongoing);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(duration: DateTime.now().difference(start));
    });
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _media.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleVideo() async {
    final next = !state.videoOff;
    await _media.setVideoOff(next);
    state = state.copyWith(videoOff: next);
  }

  Future<void> switchCamera() async {
    await _media.switchCamera();
    state = state.copyWith(isFrontCam: !state.isFrontCam);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await _media.setSpeaker(next);
    state = state.copyWith(speakerOn: next);
  }

  Future<void> hangUp({bool skipSignal = false}) async {
    _timer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();

    final inviteId = state.inviteId;
    final secs = state.duration.inSeconds;
    final wasCaller = state.isCaller;
    final wasRinging = state.status == CallStatus.ringing;

    await _media.leave();

    if (!skipSignal && inviteId != null) {
      try {
        if (wasRinging && wasCaller) {
          await _signal.cancel(inviteId);
        } else {
          await _signal.end(inviteId, durationSec: secs);
        }
      } catch (_) {}
    }

    state = const CallState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();
    _media.disposeEngine();
    _signal.dispose();
    super.dispose();
  }
}

final callProvider =
    StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier();
});
