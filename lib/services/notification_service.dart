import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/local_notification_service.dart'; // ← Ajout
import 'dart:async';

class NotificationService {
  final SupabaseClient _client;
  NotificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static const String _table = 'notifications';

  // Pour éviter de re-afficher la même notification en pop
  final Set<String> _shownPopIds = {};

  static bool _isPermanentRealtimeError(RealtimeSubscribeStatus status, Object? err) {
    if (status == RealtimeSubscribeStatus.channelError) return true;
    final msg = (err ?? '').toString().toLowerCase();
    if (msg.contains('permission denied')) return true;
    if (msg.contains('rls')) return true;
    if (msg.contains('relation') && msg.contains('does not exist')) return true;
    if (msg.contains('schema cache')) return true;
    return false;
  }

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

  /// Affiche une pop notification système si la notif est nouvelle et non lue
  Future<void> _maybeShowPop(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString();
    if (id == null) return;
    if (notif['read'] == true) return;
    if (_shownPopIds.contains(id)) return;

    _shownPopIds.add(id);

    // Garde seulement les 100 derniers pour éviter une fuite mémoire
    if (_shownPopIds.length > 100) {
      _shownPopIds.remove(_shownPopIds.first);
    }

    try {
      await LocalNotificationService.instance.show(
        id: id.hashCode,
        title: notif['title'] ?? 'THIX ID',
        body: notif['body'] ?? '',
        payload: id,
      );
    } catch (e) {
      debugPrint('NotificationService: failed to show pop → $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamForUser(String uid) {
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

        debugPrint('NotificationService: emitLatest ok uid=\( uid count= \){list.length}');

        // ← NOUVEAU : Affiche une pop pour la notification la plus récente non lue
        if (list.isNotEmpty) {
          unawaited(_maybeShowPop(list.first));
        }

        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService: emitLatest failed uid=$uid err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('NotificationService: switching to polling fallback uid=$uid');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        unawaited(emitLatest());
      },
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled) return;
      retryTimer?.cancel();
      if (polling) return;

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
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
              callback: (payload) {
                debugPrint('NotificationService: realtime change uid=\( uid table= \){payload.table}');
                unawaited(emitLatest());
              },
            )
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
                debugPrint('NotificationService: retry subscribe (attempt=\( closedRetries, delay= \){delayMs}ms) uid=$uid');
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

  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  /// Ajoute une notification + affiche immédiatement une pop
  Future<void> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
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
      } catch (e) {
        debugPrint('NotificationService: insert with rich schema failed, retrying legacy. err=$e');
        await _client.from(_table).insert({
          'user_id': toUid,
          'title': title,
          'message': body,
          'seen': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // ← NOUVEAU : Pop immédiate
      await LocalNotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: type,
      );
    } catch (e) {
      debugPrint('NotificationService: add failed to=$toUid type=$type err=$e');
      rethrow;
    }
  }

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
