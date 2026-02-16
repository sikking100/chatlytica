import 'package:intl/intl.dart';

class ChatMessage {
  final DateTime dateTime;
  final String? sender;
  final String message;
  final bool isSystem;

  ChatMessage({required this.dateTime, required this.sender, required this.message, this.isSystem = false});
}

class Participant {
  final String name;

  Participant(this.name);
}

List<Participant> extractParticipants(List<ChatMessage> messages) {
  final names = messages.where((m) => !m.isSystem && m.sender != null).map((m) => m.sender!).toSet().toList();

  if (names.length != 2) {
    throw Exception("Chat must contain exactly 2 participants");
  }

  return names.map((e) => Participant(e)).toList();
}

class ParticipantStats {
  final String name;
  final int totalMessages;
  final double avgResponseTime;
  final double avgMessageLength;
  final double initiationRatio;

  ParticipantStats({
    required this.name,
    required this.totalMessages,
    required this.avgResponseTime,
    required this.avgMessageLength,
    required this.initiationRatio,
  });
}

class AnalyticsResult {
  final ParticipantStats participantA;
  final ParticipantStats participantB;

  final double responsiveness;
  final double balance;
  final double engagement;
  final double stability;
  final double compatibilityScore;

  AnalyticsResult({
    required this.participantA,
    required this.participantB,
    required this.responsiveness,
    required this.balance,
    required this.engagement,
    required this.stability,
    required this.compatibilityScore,
  });
}

class ChatParser {
  static final RegExp _messageRegex = RegExp(r'^\[(\d{1,2}\/\d{1,2}\/\d{2,4}),\s(\d{1,2}[:.]\d{2}[:.]\d{2})\]\s(.*)$');

  static List<ChatMessage> parse(String rawText) {
    final lines = rawText.split('\n');
    List<ChatMessage> messages = [];

    for (var line in lines) {
      final match = _messageRegex.firstMatch(line);

      if (match == null) continue;

      final datePart = match.group(1)!;
      var timePart = match.group(2)!;
      final contentPart = match.group(3)!;

      // Normalize time separator (Android pakai titik)
      timePart = timePart.replaceAll('.', ':');

      final dateTime = _parseDateTime(datePart, timePart);

      if (dateTime == null) continue;

      // Split sender & message
      String? sender;
      String message;
      bool isSystem = false;

      if (contentPart.contains(':')) {
        final index = contentPart.indexOf(':');
        sender = contentPart.substring(0, index).trim();
        message = contentPart.substring(index + 1).trim();
      } else {
        // System message
        sender = null;
        message = contentPart.trim();
        isSystem = true;
      }

      messages.add(ChatMessage(dateTime: dateTime, sender: sender, message: message, isSystem: isSystem));
    }

    return messages;
  }

  static DateTime? _parseDateTime(String date, String time) {
    final possibleFormats = ['dd/MM/yy HH:mm:ss', 'dd/MM/yyyy HH:mm:ss'];

    for (var format in possibleFormats) {
      try {
        return DateFormat(format).parse("$date $time");
      } catch (_) {}
    }

    return null;
  }
}
