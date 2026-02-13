class ChatMessage {
  final DateTime dateTime;
  final String? sender;
  final String message;
  final bool isSystem;

  ChatMessage({required this.dateTime, required this.sender, required this.message, this.isSystem = false});
}

List<ChatMessage> parseChat(String content) {
  final lines = content.split('\n');
  final List<ChatMessage> messages = [];

  final RegExp chatRegex = RegExp(r'^(\d{2}\/\d{2}\/\d{2}) (\d{2}\.\d{2}) - (.*)$');

  for (var line in lines) {
    final match = chatRegex.firstMatch(line.trim());

    if (match != null) {
      final datePart = match.group(1)!;
      final timePart = match.group(2)!;
      final rest = match.group(3)!;

      final dateTime = DateTime.parse(
        "20${datePart.substring(6, 8)}-${datePart.substring(3, 5)}-${datePart.substring(0, 2)} "
        "${timePart.replaceAll('.', ':')}:00",
      );

      String? sender;
      String message;
      bool isSystem = false;

      if (rest.contains(':')) {
        final splitIndex = rest.indexOf(':');
        sender = rest.substring(0, splitIndex).trim();
        message = rest.substring(splitIndex + 1).trim();
      } else {
        // Pesan sistem
        isSystem = true;
        message = rest.trim();
      }

      messages.add(ChatMessage(dateTime: dateTime, sender: sender, message: message, isSystem: isSystem));
    }
  }

  return messages;
}

class AnalyticsResult {
  final int totalMessagesMe;
  final int totalMessagesPartner;

  final double avgResponseMe; // dalam menit
  final double avgResponsePartner;

  final double avgMessageLengthMe;
  final double avgMessageLengthPartner;

  final double initiationRatioMe; // 0–1

  final Map<String, int> dailyCount; // yyyy-MM-dd -> jumlah pesan

  // Radar score
  final double responsiveness;
  final double consistency;
  final double effortBalance;
  final double engagement;
  final double stability;

  AnalyticsResult({
    required this.totalMessagesMe,
    required this.totalMessagesPartner,
    required this.avgResponseMe,
    required this.avgResponsePartner,
    required this.avgMessageLengthMe,
    required this.avgMessageLengthPartner,
    required this.initiationRatioMe,
    required this.dailyCount,
    required this.responsiveness,
    required this.consistency,
    required this.effortBalance,
    required this.engagement,
    required this.stability,
  });
}
