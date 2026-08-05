import 'chat_message.dart';


class ChatConversation {
  final String id;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final List<String> participantIds;
  final String? otherParticipantName;
  final String? otherParticipantAvatar;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isPinned;

  ChatConversation({
    required this.id,
    required this.isGroup,
    this.groupName,
    this.groupAvatar,
    required this.participantIds,
    this.otherParticipantName,  // 👈 AJOUTÉ
    this.otherParticipantAvatar,  // 👈 AJOUTÉ
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.isPinned = false,
  });

  String get displayName {
    if (isGroup) {
      return groupName ?? 'Groupe';
    }
    return otherParticipantName ?? 'Utilisateur inconnu';
  }

  String? get displayAvatar {
    if (isGroup) {
      return groupAvatar;
    }
    return otherParticipantAvatar;
  }

  /// Copie immuable avec remplacement sélectif des champs.
  /// Utilisé notamment par ChatListNotifier.markAsRead() pour mettre
  /// unreadCount à 0 de façon optimiste sans reconstruire tout l'objet
  /// depuis JSON.
  ChatConversation copyWith({
    String? id,
    bool? isGroup,
    String? groupName,
    String? groupAvatar,
    List<String>? participantIds,
    String? otherParticipantName,
    String? otherParticipantAvatar,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      participantIds: participantIds ?? this.participantIds,
      otherParticipantName: otherParticipantName ?? this.otherParticipantName,
      otherParticipantAvatar: otherParticipantAvatar ?? this.otherParticipantAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      isGroup: json['is_group'] ?? false,
      groupName: json['group_name'],
      groupAvatar: json['group_avatar'],
      participantIds: (json['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      otherParticipantName: json['other_participant_name'],
      otherParticipantAvatar: json['other_participant_avatar'],
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'is_group': isGroup,
    'group_name': groupName,
    'group_avatar': groupAvatar,
    'participant_ids': participantIds,
    'other_participant_name': otherParticipantName,
    'other_participant_avatar': otherParticipantAvatar,
    'unread_count': unreadCount,
    'updated_at': updatedAt.toIso8601String(),
    'is_pinned': isPinned,
  };
}
