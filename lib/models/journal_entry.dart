import 'dart:convert';

enum MessageType {
  userEntry,
  aiResponse,
  aiAnalysis,
  suggestion
}

class JournalEntry {
  final int? id;
  final String content;
  final DateTime timestamp;
  final String userId;
  final MessageType messageType;
  final bool isAI;
  final Map<String, dynamic>? metadata; // For storing mood scores, emotions, etc.

  JournalEntry({
    this.id,
    required this.content,
    required this.timestamp,
    required this.userId,
    required this.messageType,
    required this.isAI,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'messageType': messageType.toString(),
      'isAI': isAI,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      userId: map['userId'],
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == map['messageType'],
      ),
      isAI: map['isAI'] == 1,
      metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
    );
  }

  // Helper constructor for user entries
  factory JournalEntry.userEntry({
    required String content,
    required String userId,
  }) {
    return JournalEntry(
      content: content,
      timestamp: DateTime.now(),
      userId: userId,
      messageType: MessageType.userEntry,
      isAI: false,
    );
  }

  // Helper constructor for AI responses
  factory JournalEntry.aiResponse({
    required String content,
    required String userId,
    required Map<String, dynamic> analysis,
  }) {
    return JournalEntry(
      content: content,
      timestamp: DateTime.now(),
      userId: userId,
      messageType: MessageType.aiResponse,
      isAI: true,
      metadata: analysis,
    );
  }
} 