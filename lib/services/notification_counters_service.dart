import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// ENUM ThixSection
// ============================================================================
enum ThixSection {
  messages,
  info,
  events,
  formations,
  opportunities,
  jobs,
}

// ============================================================================
// CLASSE SectionBadgeCounts
// ============================================================================
class SectionBadgeCounts {
  final int messages;
  final int info;
  final int events;
  final int formations;
  final int opportunities;
  final int jobs;

  const SectionBadgeCounts({
    this.messages = 0,
    this.info = 0,
    this.events = 0,
    this.formations = 0,
    this.opportunities = 0,
    this.jobs = 0,
  });

  static const zero = SectionBadgeCounts();

  factory SectionBadgeCounts.fromMap(Map<String, dynamic> map) {
    return SectionBadgeCounts(
      messages: (map['messages'] as num?)?.toInt() ?? 0,
      info: (map['info'] as num?)?.toInt() ?? 0,
      events: (map['events'] as num?)?.toInt() ?? 0,
      formations: (map['formations'] as num?)?.toInt() ?? 0,
      opportunities: (map['opportunities'] as num?)?.toInt() ?? 0,
      jobs: (map['jobs'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SectionBadgeCounts &&
        other.messages == messages &&
        other.info == info &&
        other.events == events &&
        other.formations == formations &&
        other.opportunities == opportunities &&
        other.jobs == jobs;
  }

  @override
  int get hashCode => Object.hash(
        messages,
        info,
        events,
        formations,
        opportunities,
        jobs,
      );
}

// ============================================================================
// SERVICE NotificationCountersService
// ============================================================================
class NotificationCountersService {
  NotificationCountersService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _pollingInterval = Duration(seconds: 30);
  static const _infoTable = 'info_articles';
  static const _eventsTable = 'events';
  static const _opportunitiesTable = 'opportunities';
  static const _jobsTable = 'jobs';
  static const _formationsTable = 'formations';
  static const _messagesTable = 'messages'; // ✅ Table des messages

  String _prefKey(String uid, ThixSection section) =>
      'last_seen_${uid}_${section.name}';

  Future<DateTime?> _getLastSeen(String uid, ThixSection section) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefKey(uid, section));
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e) {
      debugPrint('getLastSeen error: $e');
      return null;
    }
  }

  Future<void> _setLastSeen(String uid, ThixSection section) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefKey(uid, section),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('setLastSeen error: $e');
    }
  }

  Future<int> _countSince({
    required String table,
    required DateTime? since,
  }) async {
    try {
      var query = _client.from(table).select('id');
      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final response = await query;
      return response is List ? response.length : 0;
    } catch (e) {
      debugPrint('countSince error for $table: $e');
      return 0;
    }
  }

  /// Compte les messages non lus reçus par l'utilisateur depuis la date donnée.
  /// Utilise la colonne `receiver_id` (ou `to_uid` selon votre schéma).
  Future<int> _countMessagesSince(String uid, DateTime? since) async {
    try {
      // 🔥 On utilise _client et la table 'messages'
      var query = _client
          .from(_messagesTable)
          .select('id')
          .eq('receiver_id', uid)  // Ajuste selon ton schéma (peut être 'to_uid')
          .eq('is_read', false);
      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final response = await query;
      return response is List ? response.length : 0;
    } catch (e) {
      debugPrint('countMessagesSince error: $e');
      return 0;
    }
  }

  Future<SectionBadgeCounts> _computeCounts(String uid) async {
    // 🔥 Récupération des dernières dates de lecture
    final messagesSince = await _getLastSeen(uid, ThixSection.messages);
    final infoSince = await _getLastSeen(uid, ThixSection.info);
    final eventsSince = await _getLastSeen(uid, ThixSection.events);
    final formationsSince = await _getLastSeen(uid, ThixSection.formations);
    final opportunitiesSince = await _getLastSeen(uid, ThixSection.opportunities);
    final jobsSince = await _getLastSeen(uid, ThixSection.jobs);

    final results = await Future.wait([
      _countMessagesSince(uid, messagesSince),
      _countSince(table: _infoTable, since: infoSince),
      _countSince(table: _eventsTable, since: eventsSince),
      _countSince(table: _formationsTable, since: formationsSince),
      _countSince(table: _opportunitiesTable, since: opportunitiesSince),
      _countSince(table: _jobsTable, since: jobsSince),
    ]);

    return SectionBadgeCounts(
      messages: results[0],
      info: results[1],
      events: results[2],
      formations: results[3],
      opportunities: results[4],
      jobs: results[5],
    );
  }

  // ==========================================================================
  // MÉTHODES PUBLIQUES
  // ==========================================================================

  Future<void> markSectionSeen({
    required String uid,
    required ThixSection section,
  }) async {
    await _setLastSeen(uid, section);
  }

  Stream<SectionBadgeCounts> streamCounts(String uid) {
    final controller = StreamController<SectionBadgeCounts>.broadcast();
    Timer? pollTimer;
    bool isCancelled = false;

    Future<void> emit() async {
      if (controller.isClosed) return;
      final counts = await _computeCounts(uid);
      if (!controller.isClosed) controller.add(counts);
    }

    controller.onListen = () {
      isCancelled = false;
      unawaited(emit());
      pollTimer = Timer.periodic(_pollingInterval, (_) => unawaited(emit()));
    };

    controller.onCancel = () {
      isCancelled = true;
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream.distinct();
  }
}
