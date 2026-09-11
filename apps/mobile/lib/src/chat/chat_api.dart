import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';

class ChatApiException implements Exception {
  const ChatApiException(this.message);
  final String message;
}

class ChatConversationData {
  const ChatConversationData({
    required this.id,
    required this.type,
    required this.name,
    required this.lastMessage,
    required this.lastMessageId,
    required this.unreadCount,
    required this.updatedAt,
    required this.pinned,
    required this.muted,
    this.lastSender = '',
    this.memberCount = '',
  });

  final String id, type, name, lastMessage, lastSender, memberCount;
  final int lastMessageId, unreadCount;
  final DateTime updatedAt;
  final bool pinned, muted;

  factory ChatConversationData.fromJson(Map<String, dynamic> json) =>
      ChatConversationData(
        id: json['id'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        lastMessage: json['lastMessage'] as String? ?? '',
        lastSender: json['lastSender'] as String? ?? '',
        memberCount: json['memberCount'] as String? ?? '',
        lastMessageId: (json['lastMessageId'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        pinned: json['pinned'] as bool? ?? false,
        muted: json['muted'] as bool? ?? false,
      );
}

class ChatMessageData {
  const ChatMessageData({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.recalled,
    this.replyToMessageId = 0,
  });

  final int id, senderId, replyToMessageId;
  final String senderName, type, content;
  final DateTime createdAt;
  final bool recalled;

  factory ChatMessageData.fromJson(Map<String, dynamic> json) =>
      ChatMessageData(
        id: (json['id'] as num).toInt(),
        senderId: (json['senderId'] as num?)?.toInt() ?? 0,
        replyToMessageId: (json['replyToMessageId'] as num?)?.toInt() ?? 0,
        senderName: json['senderName'] as String,
        type: json['type'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        recalled: json['recalled'] as bool? ?? false,
      );
}

class CreatedGroupData {
  const CreatedGroupData({
    required this.id,
    required this.name,
    required this.memberCount,
    this.avatarAssetKey = '',
    this.announcement = '',
    this.joinMode = 'direct',
    this.memberInviteEnabled = true,
  });

  final String id, name, memberCount;
  final String avatarAssetKey, announcement, joinMode;
  final bool memberInviteEnabled;

  factory CreatedGroupData.fromJson(Map<String, dynamic> json) =>
      CreatedGroupData(
        id: json['id'] as String,
        name: json['name'] as String,
        memberCount: json['memberCount'] as String? ?? '1',
        avatarAssetKey: json['avatarAssetKey'] as String? ?? '',
        announcement: json['announcement'] as String? ?? '',
        joinMode: json['joinMode'] as String? ?? 'direct',
        memberInviteEnabled: json['memberInviteEnabled'] as bool? ?? true,
      );
}

class GroupDetailsData {
  const GroupDetailsData({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.avatarAssetKey,
    required this.announcement,
    required this.joinMode,
    required this.memberInviteEnabled,
    required this.role,
  });

  final String id, name, avatarAssetKey, announcement, joinMode, role;
  final int ownerUserId;
  final bool memberInviteEnabled;

  factory GroupDetailsData.fromJson(Map<String, dynamic> json) =>
      GroupDetailsData(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerUserId: (json['ownerUserId'] as num?)?.toInt() ?? 0,
        avatarAssetKey: json['avatarAssetKey'] as String? ?? '',
        announcement: json['announcement'] as String? ?? '',
        joinMode: json['joinMode'] as String? ?? 'direct',
        memberInviteEnabled: json['memberInviteEnabled'] as bool? ?? true,
        role: json['role'] as String? ?? 'member',
      );
}

class GroupMemberData {
  const GroupMemberData({
    required this.userId,
    required this.nickname,
    required this.role,
    this.mutedUntil,
  });

  final int userId;
  final String nickname, role;
  final DateTime? mutedUntil;

  factory GroupMemberData.fromJson(Map<String, dynamic> json) =>
      GroupMemberData(
        userId: (json['userId'] as num).toInt(),
        nickname: json['nickname'] as String,
        role: json['role'] as String,
        mutedUntil: json['mutedUntil'] == null
            ? null
            : DateTime.tryParse(json['mutedUntil'] as String)?.toLocal(),
      );
}

class JoinRequestData {
  const JoinRequestData({
    required this.id,
    required this.applicantUserId,
    required this.applicantName,
    required this.createdAt,
  });

  final int id, applicantUserId;
  final String applicantName;
  final DateTime createdAt;

  factory JoinRequestData.fromJson(Map<String, dynamic> json) =>
      JoinRequestData(
        id: (json['id'] as num).toInt(),
        applicantUserId: (json['applicantUserId'] as num).toInt(),
        applicantName: json['applicantName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class ChatApi {
  ChatApi({http.Client? client, AuthApi? authApi})
    : _client = client ?? http.Client(),
      _baseUrl = (authApi ?? AuthApi()).baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<List<ChatConversationData>> conversations(String token) async {
    final data = await _request('GET', '/api/v1/conversations', token);
    return (data as List<dynamic>)
        .map(
          (item) => ChatConversationData.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CreatedGroupData> createGroup(
    String token,
    String name, {
    String avatarAssetKey = '',
    String announcement = '',
    String joinMode = 'direct',
    bool memberInviteEnabled = true,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/conversations/groups',
      token,
      body: {
        'name': name,
        'avatarAssetKey': avatarAssetKey,
        'announcement': announcement,
        'joinMode': joinMode,
        'memberInviteEnabled': memberInviteEnabled,
      },
    );
    return CreatedGroupData.fromJson(data as Map<String, dynamic>);
  }

  Future<GroupDetailsData> groupDetails(
    String token,
    String conversationId,
  ) async {
    final data = await _request(
      'GET',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/group',
      token,
    );
    return GroupDetailsData.fromJson(data as Map<String, dynamic>);
  }

  Future<List<GroupMemberData>> groupMembers(
    String token,
    String conversationId,
  ) async {
    final data = await _request(
      'GET',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/members',
      token,
    );
    return (data as List<dynamic>)
        .map((item) => GroupMemberData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GroupDetailsData> updateGroup(
    String token,
    String conversationId, {
    required String avatarAssetKey,
    required String announcement,
    required String joinMode,
    required bool memberInviteEnabled,
  }) async {
    final data = await _request(
      'PATCH',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/group',
      token,
      body: {
        'avatarAssetKey': avatarAssetKey,
        'announcement': announcement,
        'joinMode': joinMode,
        'memberInviteEnabled': memberInviteEnabled,
      },
    );
    return GroupDetailsData.fromJson(data as Map<String, dynamic>);
  }

  Future<void> inviteMember(
    String token,
    String conversationId,
    int userId,
  ) => _request(
    'POST',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/members/invite',
    token,
    body: {'userId': userId},
  );

  Future<void> setMemberRole(
    String token,
    String conversationId,
    int userId,
    String role,
  ) => _request(
    'PATCH',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/members/$userId/role',
    token,
    body: {'role': role},
  );

  Future<void> setMemberMute(
    String token,
    String conversationId,
    int userId,
    DateTime? mutedUntil,
  ) => _request(
    'PATCH',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/members/$userId/mute',
    token,
    body: {'mutedUntil': mutedUntil?.toUtc().toIso8601String()},
  );

  Future<void> removeMember(
    String token,
    String conversationId,
    int userId,
  ) => _request(
    'DELETE',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/members/$userId',
    token,
  );

  Future<void> leaveGroup(String token, String conversationId) => _request(
    'DELETE',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/leave',
    token,
  );

  Future<void> transferGroupOwner(
    String token,
    String conversationId,
    int userId,
  ) => _request(
    'PATCH',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/owner',
    token,
    body: {'userId': userId},
  );

  Future<List<JoinRequestData>> joinRequests(
    String token,
    String conversationId,
  ) async {
    final data = await _request(
      'GET',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/join-requests',
      token,
    );
    final items = data is List<dynamic> ? data : const <dynamic>[];
    return items
        .map((item) => JoinRequestData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveJoinRequest(
    String token,
    String conversationId,
    int requestId,
    bool accept,
  ) => _request(
    'POST',
    '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/join-requests/$requestId/resolve',
    token,
    body: {'accept': accept},
  );

  Future<List<ChatMessageData>> messages(
    String token,
    String conversationId, {
    int? beforeId,
  }) async {
    final suffix = beforeId == null ? '' : '?beforeId=$beforeId';
    final data = await _request(
      'GET',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages$suffix',
      token,
    );
    return (data as List<dynamic>)
        .map((item) => ChatMessageData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageData> sendMessage(
    String token,
    String conversationId, {
    required String type,
    required String content,
    required String clientMessageId,
    int? replyToMessageId,
  }) async {
    final data = await _request(
      'POST',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages',
      token,
      body: {
        'type': type,
        'content': content,
        'clientMessageId': clientMessageId,
        if (replyToMessageId != null && replyToMessageId > 0)
          'replyToMessageId': replyToMessageId,
      },
    );
    return ChatMessageData.fromJson(data as Map<String, dynamic>);
  }

  Future<void> markRead(String token, String conversationId, int messageId) =>
      _request(
        'POST',
        '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/read',
        token,
        body: {'messageId': messageId},
      );

  Future<void> markAllRead(String token) =>
      _request('POST', '/api/v1/conversations/read-all', token);

  Future<dynamic> _request(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final encodedBody = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'PATCH' => await _client.patch(
          uri,
          headers: headers,
          body: encodedBody,
        ),
        'DELETE' => await _client.delete(uri, headers: headers),
        _ => await _client.post(uri, headers: headers, body: encodedBody),
      };
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatApiException(decoded['message'] as String? ?? '请求失败');
      }
      return decoded['data'];
    } on ChatApiException {
      rethrow;
    } catch (_) {
      throw const ChatApiException('无法连接消息服务器');
    }
  }
}
