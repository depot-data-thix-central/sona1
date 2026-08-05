// lib/presentation/chat/call/providers/call_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../models/chat/call_status.dart';
import '../../../../services/chat/call_service.dart';
import '../../../../services/chat/call_signaling_service.dart';

class CallState {
  final CallStatus status;
  final CallType type;
  final int? remoteUid;
  final String? inviteId;
  final String? channelName;
  final bool muted;
  final bool videoOff;
  final bool speakerOn;
  final bool isFrontCam;
  final bool isConnecting;
  final Duration duration;
  final String? errorMessage;

  const CallState({
    this.status = CallStatus.ringing,
    this.type = CallType.audio,
    this.remoteUid,
    this.inviteId,
    this.channelName,
    this.muted = false,
    this.videoOff = false,
    this.speakerOn = true,
    this.isFrontCam = true,
    this.isConnecting = true,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? type,
    int? remoteUid,
    String? inviteId,
    String? channelName,
    bool? muted,
    bool? videoOff,
    bool? speakerOn,
    bool? isFrontCam,
    bool? isConnecting,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CallState(
      status: status ?? this.status,
      type: type ?? this.type,
      remoteUid: remoteUid ?? this.remoteUid,
      inviteId: inviteId ?? this.inviteId,
      channelName: channelName ?? this.channelName,
      muted: muted ?? this.muted,
      videoOff: videoOff ?? this.videoOff,
      speakerOn: speakerOn ?? this.speakerOn,
      isFrontCam: isFrontCam ?? this.isFrontCam,
      isConnecting: isConnecting ?? this.isConnecting,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isVideo => type == CallType.video;
  bool get isOngoing => status == CallStatus.ongoing;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class CallNotifier extends AutoDisposeNotifier<CallState> {
  final CallService _call = CallService();
  final CallSignalingService _signal = CallSignalingService();

  Timer? _callTimer;
  Timer? _ringTimeout; // ← timeout appelant
  StreamSubscription? _statusSub;

  CallService get callService => _call;

  static const _ringTimeoutDuration = Duration(seconds: 45);

  int _uidFromUserId(String userId) {
    var hash = 0x811c9dc5;
    for (final c in userId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }

  @override
  CallState build() {
    ref.onDispose(() {
      _callTimer?.cancel();
      _ringTimeout?.cancel();
      _statusSub?.cancel();
      _call.dispose();
      _signal.dispose();
    });
    return const CallState();
  }

  void _cancelRingTimeout() {
    _ringTimeout?.cancel();
    _ringTimeout = null;
  }

  void _startRingTimeout() {
    _cancelRingTimeout();
    _ringTimeout = Timer(_ringTimeoutDuration, () async {
      // Si toujours en sonnerie / en attente d'accept → missed
      if (state.status == CallStatus.ringing ||
          state.status == CallStatus.accepted) {
        debugPrint('⏰ Ring timeout → missed');
        try {
          if (state.inviteId != null) {
            await _signal.update(state.inviteId!, 'missed');
          }
        } catch (_) {}
        await end(silent: true);
      }
    });
  }

  Future<void> start({
    required String channel,
    required String calleeId,
    required CallType callType,
  }) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) throw Exception('Not authenticated');

      final uid = _uidFromUserId(myId);

      debugPrint('📞 CallNotifier.start type=$callType channel=$channel callee=$calleeId');

      state = state.copyWith(
        channelName: channel,
        type: callType,
        status: CallStatus.ringing,
        isConnecting: true,
        remoteUid: null,
        videoOff: callType == CallType.audio,
        speakerOn: true,
        duration: Duration.zero,
        clearError: true,
      );

      final inviteId = await _signal.create(
        channel: channel,
        calleeId: calleeId,
        type: callType.name, // "audio" | "video"
      );
      state = state.copyWith(inviteId: inviteId);
      _listenStatusChange(inviteId);
      _startRingTimeout(); // ← timeout côté appelant

      await _call.join(
        channel: channel,
        type: callType,
        uid: uid,
        onUserJoined: (remoteUid) {
          _cancelRingTimeout();
          state = state.copyWith(
            remoteUid: remoteUid,
            status: CallStatus.ongoing,
            isConnecting: false,
            clearError: true,
          );
          _startTimer();
        },
        onUserLeft: () => end(silent: false),
        onError: (msg) {
          _cancelRingTimeout();
          state = state.copyWith(
            status: CallStatus.failed,
            isConnecting: false,
            errorMessage: msg,
          );
        },
      );
    } catch (e) {
      debugPrint('❌ CallNotifier.start error: $e');
      _cancelRingTimeout();
      state = state.copyWith(
        status: CallStatus.failed,
        isConnecting: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> accept({
    required String channel,
    required String inviteId,
    required CallType callType,
  }) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) throw Exception('Not authenticated');

      final uid = _uidFromUserId(myId);

      debugPrint('📞 CallNotifier.accept type=$callType invite=$inviteId');

      state = state.copyWith(
        inviteId: inviteId,
        channelName: channel,
        type: callType,
        status: CallStatus.accepted,
        isConnecting: true,
        videoOff: callType == CallType.audio,
        clearError: true,
      );

      await _signal.update(inviteId, 'accepted');
      _listenStatusChange(inviteId);
      // Pas de ring timeout côté callee qui a déjà accepté

      await _call.join(
        channel: channel,
        type: callType,
        uid: uid,
        onUserJoined: (remoteUid) {
          state = state.copyWith(
            remoteUid: remoteUid,
            status: CallStatus.ongoing,
            isConnecting: false,
            clearError: true,
          );
          _startTimer();
        },
        onUserLeft: () => end(silent: false),
        onError: (msg) {
          state = state.copyWith(
            status: CallStatus.failed,
            isConnecting: false,
            errorMessage: msg,
          );
        },
      );
    } catch (e) {
      debugPrint('❌ CallNotifier.accept error: $e');
      state = state.copyWith(
        status: CallStatus.failed,
        isConnecting: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> reject() async {
    _cancelRingTimeout();
    try {
      if (state.inviteId != null) {
        await _signal.update(state.inviteId!, 'rejected');
      }
    } finally {
      await _cleanup();
      state = state.copyWith(status: CallStatus.rejected);
    }
  }

  Future<void> end({bool silent = false}) async {
    _cancelRingTimeout();
    try {
      _callTimer?.cancel();
      if (!silent && state.inviteId != null) {
        await _signal.update(state.inviteId!, 'ended');
      }
      await _call.leave();
    } catch (e) {
      debugPrint('end err $e');
    } finally {
      await _cleanup();
      state = state.copyWith(status: CallStatus.ended, duration: Duration.zero);
    }
  }

  Future<void> toggleMute() async {
    final newMuted = !state.muted;
    state = state.copyWith(muted: newMuted);
    try {
      await _call.mute(newMuted);
    } catch (_) {
      state = state.copyWith(muted: !newMuted);
    }
  }

  Future<void> toggleVideo() async {
    if (state.type == CallType.audio) return;
    final newOff = !state.videoOff;
    state = state.copyWith(videoOff: newOff);
    try {
      await _call.videoOff(newOff);
    } catch (_) {
      state = state.copyWith(videoOff: !newOff);
    }
  }

  Future<void> toggleSpeaker() async {
    final newVal = !state.speakerOn;
    state = state.copyWith(speakerOn: newVal);
    try {
      await _call.speaker(newVal);
    } catch (_) {
      state = state.copyWith(speakerOn: !newVal);
    }
  }

  Future<void> switchCam() async {
    try {
      await _call.switchCam();
      state = state.copyWith(isFrontCam: !state.isFrontCam);
    } catch (_) {}
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        duration: state.duration + const Duration(seconds: 1),
      );
    });
  }

  void _listenStatusChange(String id) {
    _statusSub?.cancel();
    _statusSub = Supabase.instance.client
        .from('call_invites')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .listen((list) {
      if (list.isEmpty) return;
      final s = list.first['status'] as String?;
      if (s == 'ended' || s == 'rejected' || s == 'missed' || s == 'busy') {
        _cancelRingTimeout();
        end(silent: true);
      }
    });
  }

  Future<void> _cleanup() async {
    _callTimer?.cancel();
    _cancelRingTimeout();
    _statusSub?.cancel();
    _statusSub = null;
  }
}

final callProvider = AutoDisposeNotifierProvider<CallNotifier, CallState>(
  CallNotifier.new,
);
