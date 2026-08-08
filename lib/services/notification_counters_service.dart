import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// ENUM ThixSection (tous les modules)
// ============================================================================
enum ThixSection {
  messages,
  info,
  events,
  formations,
  opportunities,
  jobs,
  market,
  network,
  health,
  money,
  monPays,
  reservation,
  media, // TDIA
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
  final int market;
  final int network;
  final int health;
  final int money;
  final int monPays;
  final int reservation;
  final int media;

  const SectionBadgeCounts({
    this.messages = 0,
    this.info = 0,
    this.events = 0,
    this.formations = 0,
    this.opportunities = 0,
    this.jobs = 0,
    this.market = 0,
    this.network = 0,
    this.health = 0,
    this.money = 0,
    this.monPays = 0,
    this.reservation = 0,
    this.media = 0,
  });

  static const zero = SectionBadgeCounts();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SectionBadgeCounts &&
        other.messages == messages &&
        other.info == info &&
        other.events == events &&
        other.formations == formations &&
        other.opportunities == opportunities &&
        other.jobs == jobs &&
        other.market == market &&
        other.network == network &&
        other.health == health &&
        other.money == money &&
        other.monPays == monPays &&
        other.reservation == reservation &&
        other.media == media;
  }

  @override
  int get hashCode => Object.hash(
        messages,
        info,
        events,
        formations,
        opportunities,
        jobs,
        market,
        network,
        health,
        money,
        monPays,
        reservation,
        media,
      );
}

// ============================================================================
// SERVICE NotificationCountersService
// ============================================================================
class NotificationCountersService {
  NotificationCountersService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  // Polling toutes les 3 minutes
  static const _pollingInterval = Duration(seconds: 180);

  // Tables (adapte les noms si besoin selon ta base)
  static const _infoTable = 'info_articles';
  static const _eventsTable = 'events';
  static const _opportunitiesTable = 'opportunities';
  static const _jobsTable = 'jobs';
  static const _formationsTable = 'formations';
  static const _messagesTable = 'messages';
  static const _marketTable = 'market_products';      // à adapter
  static const _networkTable = 'network_posts';       // à adapter
  static const _healthTable = 'health_items';         // à adapter
  static const _moneyTable = 'money_transactions';    // à adapter
  static const _monPaysTable = 'mon_pays_items';      // à adapter
  static const _reservationTable = 'reservations';    // à adapter
  static const _mediaTable = 'reels';                 // TDIA / Media

  String _prefKey(String uid, ThixSection section) =>
      'last_seen_\( {uid}_ \){section.name}';

  Future<DateTime?> _getLastSeen(String uid, ThixSection section) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefKey(uid, section));
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e) {
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
      debugPrint('_setLastSeen error: $e');
    }
  }

  Future<int> _countSince({required String table, DateTime? since}) async {
    try {
      var query = _client.from(table).select('id');
      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final response = await query;
      return response is List ? response.length : 0;
    } catch (e) {
      // Table peut ne pas exister encore → on renvoie 0
      return 0;
    }
  }

  Future<int> _countMessagesSince(String uid, DateTime? since) async {
    try {
      var query = _client
          .from(_messagesTable)
          .select('id')
          .eq('receiver_id', uid)
          .eq('is_read', false);

      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final response = await query;
      return response is List ? response.length : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<SectionBadgeCounts> _computeCounts(String uid) async {
    final results = await Future.wait([
      _countMessagesSince(uid, await _getLastSeen(uid, ThixSection.messages)),
      _countSince(table: _infoTable, since: await _getLastSeen(uid, ThixSection.info)),
      _countSince(table: _eventsTable, since: await _getLastSeen(uid, ThixSection.events)),
      _countSince(table: _formationsTable, since: await _getLastSeen(uid, ThixSection.formations)),
      _countSince(table: _opportunitiesTable, since: await _getLastSeen(uid, ThixSection.opportunities)),
      _countSince(table: _jobsTable, since: await _getLastSeen(uid, ThixSection.jobs)),
      _countSince(table: _marketTable, since: await _getLastSeen(uid, ThixSection.market)),
      _countSince(table: _networkTable, since: await _getLastSeen(uid, ThixSection.network)),
      _countSince(table: _healthTable, since: await _getLastSeen(uid, ThixSection.health)),
      _countSince(table: _moneyTable, since: await _getLastSeen(uid, ThixSection.money)),
      _countSince(table: _monPaysTable, since: await _getLastSeen(uid, ThixSection.monPays)),
      _countSince(table: _reservationTable, since: await _getLastSeen(uid, ThixSection.reservation)),
      _countSince(table: _mediaTable, since: await _getLastSeen(uid, ThixSection.media)),
    ]);

    return SectionBadgeCounts(
      messages: results[0],
      info: results[1],
      events: results[2],
      formations: results[3],
      opportunities: results[4],
      jobs: results[5],
      market: results[6],
      network: results[7],
      health: results[8],
      money: results[9],
      monPays: results[10],
      reservation: results[11],
      media: results[12],
    );
  }

  Future<void> markSectionSeen({
    required String uid,
    required ThixSection section,
  }) async {
    await _setLastSeen(uid, section);
  }

  Stream<SectionBadgeCounts> streamCounts(String uid) {
    final controller = StreamController<SectionBadgeCounts>.broadcast();
    Timer? pollTimer;

    Future<void> emit() async {
      if (controller.isClosed) return;
      final counts = await _computeCounts(uid);
      if (!controller.isClosed) controller.add(counts);
    }

    controller.onListen = () {
      unawaited(emit());
      pollTimer = Timer.periodic(_pollingInterval, (_) => unawaited(emit()));
    };

    controller.onCancel = () {
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream.distinct();
  }
}
