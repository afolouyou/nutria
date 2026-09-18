import 'message.dart';

class Conversation {
  final String id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  List<Message>? messages;

  Conversation({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
    this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      title: (json['title'] ?? 'New conversation').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      messages: _parseMessages(json['messages']),
    );
  }

  static List<Message>? _parseMessages(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Message.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (messages != null)
        'messages': messages!.map((m) => m.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Conversation && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Conversation($id): $title';
}
