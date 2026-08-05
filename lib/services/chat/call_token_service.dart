// lib/services/chat/call_token_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallTokenService {
  final SupabaseClient _client = Supabase.instance.client;
  final Map<String, _CachedToken> _cache = {};

  static const Duration _cacheTtl = Duration(minutes: 50);
  static const Duration _timeout = Duration(seconds: 12);

  Future<Map<String, String>> getToken({
    required String channel,
    required int uid,
  }) async {
    final cacheKey = '$channel:$uid';
    final now = DateTime.now();

    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.createdAt) < _cacheTtl) {
      debugPrint('🎟️ Token cache hit → $channel');
      return {'token': cached.token, 'appId': cached.appId};
    }

    Exception? lastError;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        debugPrint('🔑 Requesting agora-token (attempt $attempt)...');

        final res = await _client.functions
            .invoke(
              'agora-token',
              body: {
                'channelName': channel,
                'uid': uid,
                'role': 'publisher',
                'expire': 3600,
              },
            )
            .timeout(_timeout);

        if (res.data == null) {
          throw Exception('Empty response from agora-token');
        }

        final data = Map<String, dynamic>.from(res.data as Map);

        final token = data['token'] as String?;
        final appId = (data['appId'] ?? data['app_id']) as String?;

        if (token == null || token.isEmpty) {
          throw Exception('Token missing: $data');
        }
        if (appId == null || appId.isEmpty) {
          throw Exception('appId missing: $data');
        }

        _cache[cacheKey] = _CachedToken(
          token: token,
          appId: appId,
          createdAt: now,
        );

        debugPrint('✅ Token OK for $channel (uid=$uid)');
        return {'token': token, 'appId': appId};
      } on TimeoutException {
        lastError = Exception('agora-token timeout (attempt $attempt)');
        debugPrint('⏱️ $lastError');
      } catch (e) {
        lastError = Exception('agora-token error: $e');
        debugPrint('❌ $lastError');
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }
    }

    // Fallback cache expiré
    if (cached != null) {
      debugPrint('⚠️ Using expired cache as fallback');
      return {'token': cached.token, 'appId': cached.appId};
    }

    throw lastError ?? Exception('Failed to get Agora token');
  }

  void clearCache() => _cache.clear();
  void invalidate(String channel, int uid) => _cache.remove('$channel:$uid');
}

class _CachedToken {
  final String token;
  final String appId;
  final DateTime createdAt;

  _CachedToken({
    required this.token,
    required this.appId,
    required this.createdAt,
  });
}
