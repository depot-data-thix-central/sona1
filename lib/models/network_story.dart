import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NetworkStory {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userTitle;
  final String imageUrl;
  final String? textContent;
  final String mediaType;
  final int duration;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;
  final bool? isCurrentUserOverride;

  NetworkStory({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.userTitle,
    required this.imageUrl,
    this.textContent,
    this.mediaType = 'image',
    required this.duration,
    required this.createdAt,
    required this.expiresAt,
    this.isViewed = false,
    this.isCurrentUserOverride,
  });

  factory NetworkStory.fromCreation({
    required String userId,
    required String userName,
    required String imageUrl,
    String? textContent,
    String mediaType = 'image',
    String? userAvatar,
    String? userTitle,
    int durationHours = 24,
  }) {
    final now = DateTime.now();
    return NetworkStory(
      id: '',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userTitle: userTitle ?? 'Membre THIX',
      imageUrl: imageUrl,
      textContent: textContent,
      mediaType: mediaType,
      duration: durationHours,
      createdAt: now,
      expiresAt: now.add(Duration(hours: durationHours)),
    );
  }

  // FIX PRINCIPAL ICI
  factory NetworkStory.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : null;

    DateTime parseDate(dynamic v, {Duration? fallbackAdd}) {
      if (v == null) {
        return DateTime.now().add(fallbackAdd ?? Duration.zero);
      }
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now().add(fallbackAdd ?? Duration.zero);
      }
    }

    // ── URL média : TOUS les alias possibles ──
    final media = (
      json['media_url'] ??
      json['image_url'] ??
      json['imageUrl'] ??
      json['mediaUrl'] ??
      json['url'] ??
      ''
    ).toString().trim();

    final name = (
      profiles?['display_name'] ??
      profiles?['full_name'] ??
      json['user_name'] ??
      json['display_name'] ??
      json['author_name'] ??
      'Utilisateur'
    ).toString();

    final avatar = (
      profiles?['avatar_url'] ??
      profiles?['photo_url'] ??
      json['user_avatar'] ??
      json['avatar_url'] ??
      json['author_avatar']
    )?.toString();

    final title = (
      profiles?['profession'] ??
      profiles?['title'] ??
      json['user_title'] ??
      json['profession'] ??
      'Membre THIX'
    ).toString();

    final text = (
      json['text_content'] ??
      json['textContent'] ??
      json['text'] ??
      ''
    ).toString();

    final type = (
      json['media_type'] ??
      json['mediaType'] ??
      (media.isNotEmpty ? 'image' : 'text')
    ).toString();

    return NetworkStory(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      userName: name,
      userAvatar: avatar,
      userTitle: title,
      imageUrl: media, // ← media_url SQL → imageUrl Flutter
      textContent: text.isEmpty ? null : text,
      mediaType: type,
      duration: (json['duration'] as num?)?.toInt() ?? 24,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      expiresAt: parseDate(
        json['expires_at'] ?? json['expiresAt'],
        fallbackAdd: const Duration(hours: 24),
      ),
      isViewed: json['is_viewed'] == true || json['isViewed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'media_url': imageUrl,
    'text': textContent, // on écrit 'text' pour compatibilité avec ton insert actuel
    'text_content': textContent, // + text_content pour le futur
    'media_type': mediaType,
    'duration': duration,
  };

  // Getters pour ne plus crasher dans StoriesList / StoryViewer
  bool get isCurrentUser {
    if (isCurrentUserOverride != null) return isCurrentUserOverride!;
    try { return Supabase.instance.client.auth.currentUser?.id == userId; } catch (_) { return false; }
  }
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;
  String get avatarUrl => userAvatar ?? '';
  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : '?';

  double get remainingPercentage {
    final total = expiresAt.difference(createdAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (1 - elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRemaining {
    final r = expiresAt.difference(DateTime.now());
    if (r.isNegative) return 'expirée';
    if (r.inHours > 0) return '${r.inHours}h';
    if (r.inMinutes > 0) return '${r.inMinutes}min';
    return 'bientôt';
  }

  NetworkStory markAsViewed() => copyWith(isViewed: true);

  NetworkStory copyWith({String? id, String? userId, String? userName, String? userAvatar, String? userTitle, String? imageUrl, String? textContent, String? mediaType, int? duration, DateTime? createdAt, DateTime? expiresAt, bool? isViewed}) {
    return NetworkStory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userTitle: userTitle ?? this.userTitle,
      imageUrl: imageUrl ?? this.imageUrl,
      textContent: textContent ?? this.textContent,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isViewed: isViewed ?? this.isViewed,
    );
  }
}

extension NetworkStoryListExtension on List<NetworkStory> {
  List<NetworkStory> get active => where((s) => !s.isExpired).toList();
  List<NetworkStory> get unviewed => where((s) => !s.isViewed).toList();
  List<NetworkStory> get sortedByNewest => toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt));
  Map<String, List<NetworkStory>> groupByUser() {
    final map = <String, List<NetworkStory>>{};
    for (final s in this) { map.putIfAbsent(s.userId, ()=> []).add(s); }
    return map;
  }
}
