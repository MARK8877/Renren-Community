import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.author,
    required this.content,
    required this.tags,
    required this.createdAt,
    this.groupId,
    this.groupName,
    this.groupMemberCount,
  });

  final String id, author, content;
  final List<String> tags;
  final DateTime createdAt;
  final String? groupId, groupName, groupMemberCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'content': content,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'groupId': groupId,
    'groupName': groupName,
    'groupMemberCount': groupMemberCount,
  };

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id'] as String,
    author: json['author'] as String,
    content: json['content'] as String,
    tags: (json['tags'] as List<dynamic>).cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    groupId: json['groupId'] as String?,
    groupName: json['groupName'] as String?,
    groupMemberCount: json['groupMemberCount'] as String?,
  );
}

class CommunityPostStore {
  static String _key(String author) => 'community_posts:$author';

  Future<List<CommunityPost>> load(String author) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final source = preferences.getString(_key(author));
      if (source == null || source.isEmpty) return [];
      return (jsonDecode(source) as List<dynamic>)
          .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String author, List<CommunityPost> posts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(author),
      jsonEncode(posts.map((post) => post.toJson()).toList()),
    );
  }
}
