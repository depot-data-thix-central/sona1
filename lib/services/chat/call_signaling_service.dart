// lib/services/chat/call_signaling_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat/call_invite.dart';
import '../../models/chat/call_status.dart';

class CallSignalingService {
  final SupabaseClient _db = Supabase.instance.client;

  RealtimeChannel? _incomingChannel;
  final Map<String, RealtimeChannel> _statusChannels = {};

  String get _uid => _db.auth.currentUser?.id ?? '';

  // ============================================================
  // START CALL
  // ============================================================

  /// Démarre un appel. Retourne l'invite (status ringing | busy).
  Future<CallInvite> startCall({
    required String calleeId,
    required CallType type,
  }) async {
    if (_uid.isEmpty) {
      throw Exception('Non authentifié');
    }
    if (calleeId.isEmpty) {
      throw Exception('calleeId vide');
    }
    if (calleeId == _uid) {
      throw Exception('Impossible de s’appeler soi-même');
    }

    final res = await _db.rpc(
      'rpc_start_call',
      params: {
        'p_callee_id': calleeId,
        'p_call_type': type == CallType.video ? 'video' : 'audio',
      },
    );

    debugPrint('📞 rpc_start_call raw: $res');

    final row = _asMap(res);
    if (row.isEmpty) {
      throw Exception('rpc_start_call a renvoyé une réponse vide');
    }

    return CallInvite.fromJson({
      ...row,
      'id': row['id'] ?? row['invite_id'],
      'channel_name': row['channel_name'] ?? row['channel'],
      'caller_id': row['caller_id'] ?? _uid,
      'callee_id': row['callee_id'] ?? calleeId,
      'call_type': row['call_type'] ??
          (type == CallType.video ? 'video' : 'audio'),
      'status': row['status'] ?? 'ringing',
      'created_at':
          row['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> accept(String inviteId) async {
    await _db.rpc('rpc_accept_call', params: {'p_invite_id': inviteId});
  }

  Future<void> reject(String inviteId) async {
    await _db.rpc('rpc_reject_call', params: {'p_invite_id': inviteId});
  }

  Future<void> cancel(String inviteId) async {
    await _db.rpc('rpc_cancel_call', params: {'p_invite_id': inviteId});
  }

  Future<void> end(String inviteId, {int durationSec = 0}) async {
    await _db.rpc('rpc_end_call', params: {
      'p_invite_id': inviteId,
      'p_duration_sec': durationSec,
    });
  }

  Future<void> markOngoing(String inviteId) async {
    await _db.rpc(
      'rpc_mark_call_ongoing',
      params: {'p_invite_id': inviteId},
    );
  }

  Future<void> markMissed(String inviteId) async {
    await _db.rpc(
      'rpc_mark_call_missed',
      params: {'p_invite_id': inviteId},
    );
  }

  // ============================================================
  // REALTIME — appels entrants
  // ============================================================

  /// Stream des invites entrants (status = ringing, pour moi = callee).
  Stream<CallInvite> watchIncoming() {
    final controller = StreamController<CallInvite>.broadcast(
      onCancel: () {
        // Ne ferme pas forcément le channel global ici si d'autres écoutent
      },
    );

    final myId = _uid;
    if (myId.isEmpty) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.addError(Exception('Non authentifié'));
          controller.close();
        }
      });
      return controller.stream;
    }

    _incomingChannel?.unsubscribe();
    try {
      _db.removeChannel(_incomingChannel!);
    } catch (_) {}

    final chName =
        'calls_in_\( {myId}_ \){DateTime.now().millisecondsSinceEpoch}';
    _incomingChannel = _db.channel(chName);

    _incomingChannel!
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
              if (row.isEmpty) return;

              final status = row['status']?.toString();
              if (status != 'ringing') return;
              if (row['caller_id']?.toString() == myId) return;

              final invite = CallInvite.fromJson(
                Map<String, dynamic>.from(row),
              );
              debugPrint('📞 Incoming call ${invite.id}');
              if (!controller.isClosed) {
                controller.add(invite);
              }
            } catch (e, st) {
              debugPrint('❌ incoming parse: $e\n$st');
            }
          },
        )
        .subscribe((status, [err]) {
          debugPrint('🔔 incoming channel: $status err=$err');
        });

    controller.onCancel = () {
      // Optionnel : ne pas kill si GlobalCallListener reste actif
    };

    return controller.stream;
  }

  // ============================================================
  // REALTIME — status d’un invite (côté caller)
  // ============================================================

  Stream<CallStatus> watchInviteStatus(String inviteId) {
    final controller = StreamController<CallStatus>.broadcast();

    // Nettoie un éventuel channel précédent pour cet id
    final old = _statusChannels.remove(inviteId);
    if (old != null) {
      try {
        old.unsubscribe();
        _db.removeChannel(old);
      } catch (_) {}
    }

    final ch = _db.channel('call_status_$inviteId');
    _statusChannels[inviteId] = ch;

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
            try {
              final s =
                  payload.newRecord['status']?.toString() ?? 'ended';
              final status = CallStatus.fromString(s);
              debugPrint('📡 invite $inviteId → $status');
              if (!controller.isClosed) {
                controller.add(status);
              }
            } catch (e) {
              debugPrint('❌ status parse: $e');
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      final c = _statusChannels.remove(inviteId);
      if (c != null) {
        try {
          c.unsubscribe();
          _db.removeChannel(c);
        } catch (_) {}
      }
    };

    return controller.stream;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _asMap(dynamic res) {
    if (res == null) return {};

    if (res is List) {
      if (res.isEmpty) return {};
      final first = res.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
      return {};
    }

    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }

    return {};
  }

  /// Libère tous les channels
  void dispose() {
    try {
      _incomingChannel?.unsubscribe();
      if (_incomingChannel != null) {
        _db.removeChannel(_incomingChannel!);
      }
    } catch (_) {}
    _incomingChannel = null;

    for (final ch in _statusChannels.values) {
      try {
        ch.unsubscribe();
        _db.removeChannel(ch);
      } catch (_) {}
    }
    _statusChannels.clear();
  }
}
