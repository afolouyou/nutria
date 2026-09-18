class Message {
  final String id;
  final String role;
  final String text;
  final DateTime? createdAt;
  final Map<String, dynamic>? card;

  const Message({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
    this.card,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawCard = json['card'] ?? json['recipe'];
    return Message(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      role: (json['role'] ?? 'assistant').toString(),
      text: (json['text'] ?? json['content'] ?? '').toString(),
      card: rawCard is Map<String, dynamic> ? rawCard : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'text': text,
      if (card != null) 'card': card,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Message copyWith({String? text, Map<String, dynamic>? card}) {
    return Message(
      id: id,
      role: role,
      text: text ?? this.text,
      card: card ?? this.card,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && other.id == id && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(id, role, text);

  @override
  String toString() => 'Message($role): $text';
}