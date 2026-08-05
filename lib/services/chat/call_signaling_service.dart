// Route: lib/services/chat/call_signaling_service.dart
// PRODUCTION - Signaling Supabase Realtime - Anti-duplicate - Busy check
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat/call_invite.dart';
import '../../models/chat/call_status.dart';

class CallSignalingService {
  final SupabaseClient _db = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription? _pollSub;
  bool _isListening = false;

  // ============================================================
  // LISTEN - Ecoute mes appels entrants
  // ============================================================
  void listenMyInvites(
    String myId,
    Function(CallInvite invite) onRinging,
  ) {
    if (_isListening) return;
    _isListening = true;

    _channel?.unsubscribe();
    if (_channel!= null) {
      _db.removeChannel(_channel!);
    }

    final chName = 'calls:$myId:${DateTime.now().millisecondsSinceEpoch}';
    _channel = _db.channel(chName);

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
          callback: (payload) async {
            try {
              final row = payload.newRecord;
              if (row.isEmpty) return;

              final status = row['status'] as String?;
              if (status!= 'ringing') return;

              final invite = CallInvite.fromJson(row);

              // Anti self-call
              if (invite.callerId == myId) return;

              // Busy check : si j'ai déjà un call en cours, je refuse direct
              final busy = await _isBusy(myId);
              if (busy) {
                await update(invite.id, 'busy');
                return;
              }

              debugPrint('📞 Incoming call ${invite.id} from ${invite.callerId}');
              onRinging(invite);
            } catch (e) {
              debugPrint('❌ listenMyInvites parse error: $e');
            }
          },
        )
       .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: myId,
          ),
          callback: (payload) {
            // Optionnel: si l'appelant annule, tu peux fermer l'écran entrant
            final newStatus = payload.newRecord['status'];
            if (newStatus == 'ended' || newStatus == 'canceled') {
              debugPrint('📴 Caller canceled');
            }
          },
        )
       .subscribe((status, err) {
          debugPrint('🔔 Realtime status $status err $err');
        });

    // Fallback polling toutes les 8s si Realtime KO (réseau faible)
    _pollSub?.cancel();
    _pollSub = Stream.periodic(const Duration(seconds: 8)).listen((_) async {
      try {
        final rows = await _db
           .from('call_invites')
           .select()
           .eq('callee_id', myId)
           .eq('status', 'ringing')
           .order('created_at', ascending: false)
           .limit(1);

        if (rows.isNotEmpty) {
          final invite = CallInvite.fromJson(rows.first as Map<String, dynamic>);
          // Seulement si créé il y a < 30s
          final age = DateTime.now().difference(invite.createdAt).inSeconds;
          if (age < 30) {
            final busy = await _isBusy(myId);
            if (!busy) onRinging(invite);
          }
        }
      } catch (_) {}
    });
  }

  // ============================================================
  // CREATE - Création d'un appel sortant
  // ============================================================
  Future<String> create({
    required String channel,
    required String calleeId,
    required String type,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    if (uid == calleeId) throw Exception('Cannot call yourself');

    // Check callee busy
    final busy = await _isBusy(calleeId);
    if (busy) throw Exception('User is busy');

    final caller = _db.auth.currentUser;
    final meta = caller?.userMetadata;
    final callerName = meta?['full_name']?? meta?['name']?? 'Inconnu';
    final callerAvatar = meta?['avatar_url']?? meta?['picture'];

    final res = await _db
        .from('call_invites')
        .insert({
          'channel': channel,
          'caller_id': uid,
          'callee_id': calleeId,
          'call_type': type,
          'status': 'ringing',
          'caller_name': callerName,
          'caller_avatar': callerAvatar,
        })
        .select()
        .single();

    debugPrint('📤 Invite created ${res['id']} -> $calleeId');
    return res['id'] as String;
  }

  // ============================================================
  // UPDATE - Changement de statut
  // ============================================================
  Future<void> update(String id, String status) async {
    try {
      await _db
         .from('call_invites')
         .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
         .eq('id', id);
      debugPrint('📝 Invite $id -> $status');
    } catch (e) {
      debugPrint('❌ update error $e');
      rethrow;
    }
  }

  Future<void> cancel(String id) => update(id, 'canceled');
  Future<void> accept(String id) => update(id, 'accepted');
  Future<void> reject(String id) => update(id, 'rejected');
  Future<void> end(String id) => update(id, 'ended');
  Future<void> miss(String id) => update(id, 'missed');

  // ============================================================
  // HELPERS
  // ============================================================
  Future<bool> _isBusy(String userId) async {
    try {
      final rows = await _db
         .from('call_invites')
         .select('id')
         .or('caller_id.eq.$userId,callee_id.eq.$userId')
         .inFilter('status', ['ringing', 'accepted', 'ongoing'])
         .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<CallInvite?> getInvite(String id) async {
    try {
      final row = await _db.from('call_invites').select().eq('id', id).single();
      return CallInvite.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DISPOSE - Safe
  // ============================================================
  void dispose() {
    _isListening = false;
    _pollSub?.cancel();
    _pollSub = null;
    if (_channel!= null) {
      try {
        _channel!.unsubscribe();
        _db.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }
}
