import 'package:chatlytica/model.dart';

class AnalyticsService {
  AnalyticsResult analyze(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      throw Exception("No messages");
    }

    messages = messages.where((m) => !m.isSystem && m.sender != null).toList();

    messages.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final participants = extractParticipants(messages);
    final nameA = participants[0].name;
    final nameB = participants[1].name;

    int totalA = 0;
    int totalB = 0;

    double lengthA = 0;
    double lengthB = 0;

    double responseA = 0;
    double responseB = 0;

    int responseCountA = 0;
    int responseCountB = 0;

    int initiationA = 0;
    int initiationB = 0;

    int conversationCount = 0;

    Map<String, int> dailyCount = {};

    ChatMessage? previous;

    for (var msg in messages) {
      final isA = msg.sender == nameA;

      if (isA) {
        totalA++;
        lengthA += msg.message.length;
      } else {
        totalB++;
        lengthB += msg.message.length;
      }

      // daily
      final key = "${msg.dateTime.year}-${msg.dateTime.month}-${msg.dateTime.day}";
      dailyCount[key] = (dailyCount[key] ?? 0) + 1;

      // response
      if (previous != null && previous.sender != msg.sender) {
        final diff = msg.dateTime.difference(previous.dateTime).inMinutes;

        if (isA) {
          responseA += diff;
          responseCountA++;
        } else {
          responseB += diff;
          responseCountB++;
        }
      }

      // conversation start
      if (previous == null || msg.dateTime.difference(previous.dateTime).inHours > 2) {
        conversationCount++;

        if (isA) {
          initiationA++;
        } else {
          initiationB++;
        }
      }

      previous = msg;
    }

    final avgResponseA = responseCountA == 0 ? 0 : responseA / responseCountA;

    final avgResponseB = responseCountB == 0 ? 0 : responseB / responseCountB;

    final avgLengthA = totalA == 0 ? 0 : lengthA / totalA;

    final avgLengthB = totalB == 0 ? 0 : lengthB / totalB;

    final initiationRatioA = conversationCount == 0 ? 0 : initiationA / conversationCount;

    final initiationRatioB = conversationCount == 0 ? 0 : initiationB / conversationCount;

    // SCORING

    final responsiveness = _scoreResponsiveness(avgResponseA.toDouble(), avgResponseB.toDouble());

    final balance = _scoreBalance(totalA, totalB);

    final engagement = _scoreEngagement(avgLengthA.toDouble(), avgLengthB.toDouble());

    final stability = _scoreStability(dailyCount);

    final compatibility = (responsiveness + balance + engagement + stability) / 4;

    return AnalyticsResult(
      participantA: ParticipantStats(
        name: nameA,
        totalMessages: totalA,
        avgResponseTime: avgResponseA.toDouble(),
        avgMessageLength: avgLengthA.toDouble(),
        initiationRatio: initiationRatioA.toDouble(),
      ),
      participantB: ParticipantStats(
        name: nameB,
        totalMessages: totalB,
        avgResponseTime: avgResponseB.toDouble(),
        avgMessageLength: avgLengthB.toDouble(),
        initiationRatio: initiationRatioB.toDouble(),
      ),
      responsiveness: responsiveness,
      balance: balance,
      engagement: engagement,
      stability: stability,
      compatibilityScore: compatibility,
    );
  }

  double _scoreResponsiveness(double a, double b) {
    final avg = (a + b) / 2;
    return (100 - avg.clamp(0, 120)).clamp(0, 100).toDouble();
  }

  double _scoreBalance(int a, int b) {
    if (a + b == 0) return 50;
    final diff = (a - b).abs() / (a + b);
    return (100 - diff * 100).clamp(0, 100);
  }

  double _scoreEngagement(double a, double b) {
    final avg = (a + b) / 2;
    return (avg.clamp(0, 200) / 200 * 100).clamp(0, 100);
  }

  double _scoreStability(Map<String, int> dailyCount) {
    if (dailyCount.length < 2) return 50;

    final values = dailyCount.values.toList();
    double fluctuation = 0;

    for (int i = 1; i < values.length; i++) {
      fluctuation += (values[i] - values[i - 1]).abs();
    }

    fluctuation /= values.length;

    return (100 - fluctuation).clamp(0, 100);
  }
}
