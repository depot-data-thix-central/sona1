// lib/services/chat/call_signaling_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat/call_invite.dart';
import '../../models/chat/call_status.dart';

class CallSignalingService {
  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get _uid => _db.auth.currentUser?.id ?? '';

  /// Démarre un appel → {inviteId, channelName, status}
  Future<CallInvite> startCall({
    required String calleeId,
    required CallType type,
  }) async {
    final res = await _db.rpc('rpc_start_call', params: {
      'p_callee_id': calleeId,
      'p_call_type': type == CallType.video ? 'video' : 'audio',
    });

    final row = (res as List).first as Map;
    return CallInvite.fromJson({
      ...Map<String, dynamic>.from(row),
      'caller_id': _uid,
      'callee_id': calleeId,
      'call_type': type == CallType.video ? 'video' : 'audio',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> accept(String inviteId) =>
      _db.rpc('rpc_accept_call', params: {'p_invite_id': inviteId});

  Future<void> reject(String inviteId) =>
      _db.rpc('rpc_reject_call', params: {'p_invite_id': inviteId});

  Future<void> cancel(String inviteId) =>
      _db.rpc('rpc_cancel_call', params: {'p_invite_id': inviteId});

  Future<void> end(String inviteId, {int durationSec = 0}) =>
      _db.rpc('rpc_end_call', params: {
        'p_invite_id': inviteId,
        'p_duration_sec': durationSec,
      });

  Future<void> markOngoing(String inviteId) =>
      _db.rpc('rpc_mark_call_ongoing', params: {'p_invite_id': inviteId});

  Future<void> markMissed(String inviteId) =>
      _db.rpc('rpc_mark_call_missed', params: {'p_invite_id': inviteId});

  /// Écoute les appels entrants (Realtime)
  Stream<CallInvite> watchIncoming() {
    final controller = StreamController<CallInvite>.broadcast();
    final myId = _uid;
    if (myId.isEmpty) {
      controller.close();
      return controller.stream;
    }

    _channel?.unsubscribe();
    _channel = _db.channel('calls_in_$myId');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: myId,
          ),
          callback: (payload) {
            try {
              final row = payload.newRecord;
              if (row['status'] != 'ringing') return;
              if (row['caller_id'] == myId) return;
              controller.add(CallInvite.fromJson(row));
            } catch (e) {
              debugPrint('❌ incoming parse: $e');
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _channel?.unsubscribe();
    };

    return controller.stream;
  }

  /// Écoute le status d’un invite (caller côté)
  Stream<CallStatus> watchInviteStatus(String inviteId) {
    final controller = StreamController<CallStatus>.broadcast();

    final ch = _db.channel('call_status_$inviteId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: inviteId,
          ),
          callback: (payload) {
            final s = payload.newRecord['status']?.toString() ?? 'ended';
            controller.add(CallStatus.fromString(s));
          },
        )
        .subscribe();

    controller.onCancel = () {
      _db.removeChannel(ch);
    };

    return controller.stream;
  }

  void dispose() {
    _channel?.unsubscribe();
  }
}
