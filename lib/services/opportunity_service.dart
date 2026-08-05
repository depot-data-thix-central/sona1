import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/opportunity_application.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class OpportunityService {
  static const String table = 'thix_opportunities';
  static const _kOpps = 'thix_opportunities_v1';
  static const _kApplications = 'thix_opportunity_applications_v1';

  /// Supabase Storage bucket for opportunity images.
  /// Create it in Supabase → Storage (public recommended).
  static const String imageBucket = 'thix_opportunity_images';

  /// Upload an image to Supabase Storage and return a public URL.
  Future<String> uploadOpportunityImage({required Uint8List bytes, required String extension}) async {
    final ext = extension.trim().isEmpty ? 'jpg' : extension.trim().toLowerCase();
    final uid = SupabaseConfig.currentUser?.id ?? 'anon';
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final objectPath = 'opportunities/$uid/$ts.$ext';

    try {
      await SupabaseConfig.storage.from(imageBucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: ext == 'png'
                  ? 'image/png'
                  : ext == 'webp'
                      ? 'image/webp'
                      : ext == 'gif'
                          ? 'image/gif'
                          : 'image/jpeg',
            ),
          );
      final url = SupabaseConfig.storage.from(imageBucket).getPublicUrl(objectPath);
      if (url.trim().isEmpty) throw Exception('Storage: getPublicUrl returned empty.');
      return url;
    } catch (e) {
      final msg = e.toString();
      debugPrint('OpportunityService.uploadOpportunityImage failed err=$msg');
      if (msg.contains('Bucket') && msg.contains('not found')) {
        throw Exception("Bucket Supabase Storage introuvable: '$imageBucket'. Crée-le (public) dans Supabase → Storage.");
      }
      throw Exception('Upload image échoué: $msg');
    }
  }

  Future<List<OpportunityItem>> listOpportunities() async {
    // 1) Try Supabase first so Admin content is visible.
    try {
      final res = await SupabaseService.select(
        table,
        select: '*',
        orderBy: 'created_at',
        ascending: false,
        limit: 200,
      );
      final items = _mapRows(res);
      if (items.isNotEmpty) {
        await _cache(items);
        return items;
      }
    } catch (e) {
      debugPrint('OpportunityService.listOpportunities supabase failed err=$e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kOpps);
      if (raw == null || raw.trim().isEmpty) {
        final seeded = _seed();
        await prefs.setString(_kOpps, OpportunityItem.encodeList(seeded));
        return seeded;
      }
      final items = OpportunityItem.decodeList(raw);
      if (items.isEmpty) {
        final seeded = _seed();
        await prefs.setString(_kOpps, OpportunityItem.encodeList(seeded));
        return seeded;
      }
      return items;
    } catch (e) {
      debugPrint('OpportunityService.listOpportunities failed err=$e');
      return _seed();
    }
  }

  Future<void> createOpportunity(OpportunityItem item) async {
    try {
      final payload = <String, dynamic>{
        'title': item.title,
        'organizer': item.organizer,
        'location': item.location,
        'category': item.category,
        'reward_label': item.rewardLabel,
        'deadline_label': item.deadlineLabel,
        'deadline': item.deadline.toIso8601String(),
        'description': item.description,
        'eligibility': item.eligibility,
        'apply_url': item.applyUrl,
        if (item.imageAssetPath != null && item.imageAssetPath!.trim().isNotEmpty) 'image_url': item.imageAssetPath,
        'status': 'pending',
      };
      await SupabaseService.insert(table, payload);
    } catch (e) {
      debugPrint('OpportunityService.createOpportunity supabase failed err=$e');
      rethrow;
    }
  }

  Future<OpportunityItem?> fetchOpportunity(String id) async {
    final v = id.trim();
    if (v.isEmpty) return null;
    final all = await listOpportunities();
    for (final o in all) {
      if (o.id == v) return o;
    }
    return null;
  }

  Future<void> submitApplication({
    required String opportunityId,
    required String applicantThixId,
    required String message,
  }) async {
    final now = DateTime.now();
    final app = OpportunityApplication(
      id: _id('oppapp'),
      opportunityId: opportunityId,
      applicantThixId: applicantThixId.trim().toUpperCase(),
      message: message.trim().isEmpty ? null : message.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kApplications);
      final list = (raw == null || raw.trim().isEmpty) ? <OpportunityApplication>[] : OpportunityApplication.decodeList(raw).toList(growable: true);
      list.insert(0, app);
      await prefs.setString(_kApplications, OpportunityApplication.encodeList(list));
    } catch (e) {
      debugPrint('OpportunityService.submitApplication failed err=$e');
      rethrow;
    }
  }

  String _id(String prefix) {
    final rnd = Random.secure();
    final n = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${prefix}_$n';
  }

  List<OpportunityItem> _mapRows(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    DateTime parseDate(dynamic v) {
      if (v == null) return now;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? now;
    }

    String pick(Map<String, dynamic> r, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = r[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    List<String> pickList(Map<String, dynamic> r, List<String> keys) {
      for (final k in keys) {
        final v = r[k];
        if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
      }
      return const <String>[];
    }

    return rows.map((r) {
      final id = pick(r, const ['id', 'uuid'], fallback: _id('opp'));
      final title = pick(r, const ['title', 'name'], fallback: '—');
      final organizer = pick(r, const ['organizer', 'organization', 'company'], fallback: '');
      final location = pick(r, const ['location', 'city'], fallback: '');
      final category = pick(r, const ['category', 'type'], fallback: 'Opportunité');
      final rewardLabel = pick(r, const ['reward_label', 'rewardLabel', 'reward'], fallback: '');
      final deadlineLabel = pick(r, const ['deadline_label', 'deadlineLabel'], fallback: '');
      final deadline = parseDate(r['deadline'] ?? r['deadline_at']);
      final description = pick(r, const ['description', 'content'], fallback: '');
      final eligibility = pickList(r, const ['eligibility', 'requirements']);
      final applyUrl = pick(r, const ['apply_url', 'applyUrl', 'url'], fallback: '');
      final imageUrl = pick(r, const ['image_url', 'imageUrl', 'cover_url', 'coverUrl'], fallback: '');
      return OpportunityItem(
        id: id,
        title: title,
        organizer: organizer,
        location: location,
        category: category,
        rewardLabel: rewardLabel.isEmpty ? '—' : rewardLabel,
        deadlineLabel: deadlineLabel.isEmpty ? '—' : deadlineLabel,
        deadline: deadline,
        description: description,
        eligibility: eligibility,
        applyUrl: applyUrl,
        // In app UI we currently use Image.asset. If Supabase provides URLs, we still store it here.
        // The UI will be adapted later to support network images.
        imageAssetPath: imageUrl.isEmpty ? null : imageUrl,
        createdAt: parseDate(r['created_at'] ?? r['createdAt']),
        updatedAt: parseDate(r['updated_at'] ?? r['updatedAt']),
      );
    }).toList(growable: false);
  }

  Future<void> _cache(List<OpportunityItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOpps, OpportunityItem.encodeList(items));
    } catch (e) {
      debugPrint('OpportunityService cache failed err=$e');
    }
  }

  List<OpportunityItem> _seed() {
    final now = DateTime.now();
    DateTime d(int days) => DateTime(now.year, now.month, now.day).add(Duration(days: days));
    return [
      OpportunityItem(
        id: 'opp_startup_grant',
        title: 'Bourse Startup • Subvention Innovation 2024',
        organizer: 'THIX Innovation Lab',
        location: 'Kinshasa • Hybride',
        category: 'Subvention',
        rewardLabel: 'Jusqu’à 15 000 USD',
        deadlineLabel: 'Clôture dans 10 jours',
        deadline: d(10),
        description:
            'Programme de subvention pour projets tech/impact. Sélection accélérée pour profils THIX ID vérifiés. Pitch final devant jury + partenaires.',
        eligibility: const ['Startup < 3 ans', 'MVP prêt', 'Équipe de 2+'],
        applyUrl: 'https://thix.app/opportunities/opp_startup_grant/apply',
        imageAssetPath: 'assets/images/entrepreneur_competition_grayscale_1778649621812.jpg',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      OpportunityItem(
        id: 'opp_scholarship_ai',
        title: 'Bourse Formation • Data & IA (cohorte premium)',
        organizer: 'Fondation Numérique',
        location: 'En ligne',
        category: 'Bourse',
        rewardLabel: '100% frais + certification',
        deadlineLabel: 'Clôture dans 21 jours',
        deadline: d(21),
        description:
            'Bourse complète pour une cohorte Data/IA. Test en ligne + entretien. THIX ID requis pour sécuriser l’accès et réduire la fraude.',
        eligibility: const ['Étudiant ou professionnel', 'Bonne connexion', 'Motivation'],
        applyUrl: 'https://thix.app/opportunities/opp_scholarship_ai/apply',
        imageAssetPath: 'assets/images/tech_conference_stage_audience_grayscale_1778649599691.jpg',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      OpportunityItem(
        id: 'opp_pitch_competition',
        title: 'Concours Pitch • THIX Challenge (finale)',
        organizer: 'THIX Partners',
        location: 'Pullman Grand Hotel',
        category: 'Concours',
        rewardLabel: 'Prix + accompagnement',
        deadlineLabel: 'Clôture dans 5 jours',
        deadline: d(5),
        description:
            'Concours de pitch avec short-list et coaching. Vérification THIX ID obligatoire pour candidater et accéder à la finale.',
        eligibility: const ['Projet innovant', 'Pitch deck', 'THIX ID valide'],
        applyUrl: 'https://thix.app/opportunities/opp_pitch_competition/apply',
        imageAssetPath: 'assets/images/Office_team_grayscale_1775574009745.jpg',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
    ];
  }
}
