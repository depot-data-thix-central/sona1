import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'dart:async';

class NotificationService {
  final SupabaseClient _client;
  NotificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// IMPORTANT: In this Supabase project, the verified table name is `notifications`.
  ///
  /// We still normalize rows so the UI always receives:
  /// `{id,user_id,type,title,body,read,data,created_at}` regardless of DB column variants.
  static const String _table = 'notifications';

  /// Détermine si le statut/erreur Realtime est permanent et non récupérable
  static bool _isPermanentRealtimeError(RealtimeSubscribeStatus status, Object? err) {
    if (status == RealtimeSubscribeStatus.channelError) return true;
    final msg = (err ?? '').toString().toLowerCase();
    // Causes permanentes communes: table manquante, publication manquante, RLS refusée.
    if (msg.contains('permission denied')) return true;
    if (msg.contains('rls')) return true;
    if (msg.contains('relation') && msg.contains('does not exist')) return true;
    if (msg.contains('schema cache')) return true;
    return false;
  }

  /// Normalise les lignes reçues de Supabase pour assurer un format cohérent
  Map<String, dynamic> _normalizeRow(Map<String, dynamic> r) {
    final data = (r['data'] is Map)
        ? (r['data'] as Map).cast<String, dynamic>()
        : (r['payload'] is Map)
            ? (r['payload'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{};
    final read = (r['read'] as bool?) ?? (r['seen'] as bool?) ?? false;
    return <String, dynamic>{
      'id': r['id'],
      'user_id': r['user_id'],
      'type': (r['type'] ?? r['kind'] ?? 'generic').toString(),
      'title': (r['title'] ?? 'Notification').toString(),
      'body': (r['body'] ?? r['message'] ?? r['content'] ?? '').toString(),
      'read': read,
      'data': data,
      'created_at': r['created_at'],
    };
  }

  /// Stream Realtime (préféré): utilise `postgres_changes` puis recharge.
  /// Retourne au polling si Realtime ne peut pas s'abonner.
  Stream<List<Map<String, dynamic>>> streamForUser(String uid) {
    // IMPORTANT: Ceci DOIT émettre APRÈS que le premier listener soit attaché.
    // Un StreamController broadcast abandonnera les événements ajoutés avant que
    // tout listener ne soit abonné (ce qui rend l'UI "stuck loading").
    late final StreamController<List<Map<String, dynamic>>> controller;
    final authUid = _client.auth.currentUser?.id;
    if (authUid != null && authUid != uid) {
      debugPrint('NotificationService: streamForUser uid mismatch. param=$uid auth=$authUid; using auth uid.');
      uid = authUid;
    }

    RealtimeChannel? channel;
    var closedRetries = 0;
    Timer? retryTimer;
    var isCancelled = false;
    Timer? pollTimer;
    var polling = false;

    /// Émet la dernière liste de notifications depuis la base de données
    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(_table)
            .select('*')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(50);
        final list = (rows is List)
            ? rows
                .map((e) => _normalizeRow((e as Map).cast<String, dynamic>()))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
        debugPrint('NotificationService: emitLatest ok uid=$uid count=${list.length}');
        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService: emitLatest failed uid=$uid err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    /// Bascule vers le polling en cas d'échec Realtime
    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('NotificationService: switching to polling fallback uid=$uid');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // Premier rendu: récupère l'état actuel.
        unawaited(emitLatest());
      },
    );

    /// S'abonne aux changements Realtime ou réessaye après un délai
    Future<void> subscribeOrRetry() async {
      if (isCancelled) return;
      retryTimer?.cancel();
      if (polling) return;

      // Crée un nouveau canal à chaque tentative.
      try {
        if (channel != null) await _client.removeChannel(channel!);
      } catch (_) {}

      channel = _client.channel('notifications:user:$uid');
      try {
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              // NOTE: Prefer explicit filter object (2.x API).
              // If your Realtime policies / RLS prevent visibility, we fall back to polling.
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
              callback: (payload) {
                debugPrint('NotificationService: realtime change uid=$uid table=${payload.table}');
                unawaited(emitLatest());
              },
            )
            // Some supabase_flutter versions expose `subscribe((status, [err]) {})`.
            // Using an optional positional keeps us compatible.
            .subscribe((status, [err]) {
              debugPrint('NotificationService: subscribe status=$status err=$err uid=$uid');
              if (isCancelled) return;

              if (_isPermanentRealtimeError(status, err)) {
                startPolling();
                return;
              }

              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) {
                closedRetries = 0;
                return;
              }

              closedRetries = (closedRetries + 1).clamp(1, 10);
              final delayMs = (500 * (1 << (closedRetries - 1))).clamp(500, 8000);
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs), () {
                debugPrint('NotificationService: retry subscribe (attempt=$closedRetries, delay=${delayMs}ms) uid=$uid');
                unawaited(subscribeOrRetry());
              });
            });
      } catch (e) {
        debugPrint('NotificationService: realtime wiring failed, falling back to polling. err=$e');
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());

    controller.onCancel = () async {
      isCancelled = true;
      retryTimer?.cancel();
      pollTimer?.cancel();
      final ch = channel;
      if (ch != null) await _client.removeChannel(ch);
    };

    return controller.stream;
  }

  /// Stream de commodité qui expose le nombre de notifications non lues.
  ///
  /// Utilisé pour les badges rouges (boutons Accueil, icône cloche, etc.).
  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  /// Ajoute une nouvelle notification pour un utilisateur
  Future<void> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Essayer le schéma plus riche d'abord.
      try {
        await _client.from(_table).insert({
          'user_id': toUid,
          'type': type,
          'title': title,
          'body': body,
          'read': false,
          'data': data ?? const <String, dynamic>{},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      } catch (e) {
        debugPrint('NotificationService: insert with (type,body,read,data) failed, retrying legacy columns. err=$e');
      }
      // Compatibilité schéma hérité/simple.
      await _client.from(_table).insert({
        'user_id': toUid,
        'title': title,
        'message': body,
        'seen': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('NotificationService: add failed to=$toUid type=$type err=$e');
      rethrow;
    }
  }

  /// Marque une notification comme lue
  Future<void> markRead({required String uid, required String notificationId}) async {
    try {
      try {
        await _client
            .from(_table)
            .update({'read': true})
            .eq('id', notificationId)
            .eq('user_id', uid);
        return;
      } catch (e) {
        debugPrint('NotificationService: markRead set read=true failed, retry legacy. err=$e');
      }
      await _client
          .from(_table)
          .update({'seen': true})
          .eq('id', notificationId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('NotificationService: markRead failed uid=$uid id=$notificationId err=$e');
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllRead(String uid) async {
    try {
      try {
        await _client.from(_table).update({'read': true}).eq('user_id', uid).eq('read', false);
        return;
      } catch (e) {
        debugPrint('NotificationService: markAllRead set read=true failed, retry legacy. err=$e');
      }
      await _client.from(_table).update({'seen': true}).eq('user_id', uid).eq('seen', false);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed uid=$uid err=$e');
    }
  }
}

class RealtimeListenTypes {
}
