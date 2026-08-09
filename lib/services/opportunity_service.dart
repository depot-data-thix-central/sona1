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
    try {
      // 1) On interroge Supabase en priorité
      final res = await SupabaseService.select(
        table,
        select: '*',
        orderBy: 'created_at',
        ascending: false,
        limit: 200,
      );
      final items = _mapRows(res);
      
      // On met à jour le cache local avec les vraies données (même si c'est vide)
      // Ça va écraser les anciennes fausses données qui étaient en mémoire !
      await _cache(items); 
      return items;
      
    } catch (e) {
      debugPrint('OpportunityService.listOpportunities supabase failed err=$e');
      
      // 2) En cas de perte de connexion internet, on lit le cache local
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kOpps);
        if (raw != null && raw.trim().isNotEmpty) {
          return OpportunityItem.decodeList(raw);
        }
      } catch (cacheErr) {
        debugPrint('Lecture du cache échouée: $cacheErr');
      }
      
      // Si tout échoue, on retourne une liste vide (plus de fausses données)
      return []; 
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
    // On retourne une liste vide. Les fausses données sont supprimées.
    return [];
  }
}
