import 'package:chatlytica/model.dart';

class AnalyticsService {
  final String myName;

  AnalyticsService(this.myName);

  AnalyticsResult analyze(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      throw Exception("No messages to analyze");
    }

    messages.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    int totalMe = 0;
    int totalPartner = 0;

    double totalLengthMe = 0;
    double totalLengthPartner = 0;

    double responseMe = 0;
    double responsePartner = 0;
    int responseCountMe = 0;
    int responseCountPartner = 0;

    int initiationMe = 0;
    int conversationCount = 0;

    Map<String, int> dailyCount = {};

    ChatMessage? previous;

    for (var msg in messages) {
      final isMe = msg.sender == myName;

      // Count total
      if (isMe) {
        totalMe++;
        totalLengthMe += msg.message.length;
      } else {
        totalPartner++;
        totalLengthPartner += msg.message.length;
      }

      // Daily count
      final dayKey = "${msg.dateTime.year}-${msg.dateTime.month}-${msg.dateTime.day}";
      dailyCount[dayKey] = (dailyCount[dayKey] ?? 0) + 1;

      // Response time
      if (previous != null && previous.sender != msg.sender) {
        final diff = msg.dateTime.difference(previous.dateTime).inMinutes;

        if (isMe) {
          responseMe += diff;
          responseCountMe++;
        } else {
          responsePartner += diff;
          responseCountPartner++;
        }
      }

      // Conversation start (gap > 2 jam dianggap conversation baru)
      if (previous == null || msg.dateTime.difference(previous.dateTime).inHours > 2) {
        conversationCount++;
        if (isMe) initiationMe++;
      }

      previous = msg;
    }

    final avgResponseMe = responseCountMe == 0 ? 0 : responseMe / responseCountMe;

    final avgResponsePartner = responseCountPartner == 0 ? 0 : responsePartner / responseCountPartner;

    final avgLengthMe = totalMe == 0 ? 0 : totalLengthMe / totalMe;
    final avgLengthPartner = totalPartner == 0 ? 0 : totalLengthPartner / totalPartner;

    final initiationRatioMe = conversationCount == 0 ? 0 : initiationMe / conversationCount;

    // Radar scores
    final responsiveness = _scoreResponsiveness(avgResponseMe.toDouble(), avgResponsePartner.toDouble());

    final consistency = _scoreConsistency(dailyCount);

    final effortBalance = _scoreEffortBalance(totalMe, totalPartner, initiationRatioMe.toDouble());

    final engagement = _scoreEngagement(avgLengthMe.toDouble(), avgLengthPartner.toDouble());

    final stability = _scoreStability(dailyCount);

    return AnalyticsResult(
      totalMessagesMe: totalMe,
      totalMessagesPartner: totalPartner,
      avgResponseMe: avgResponseMe.toDouble(),
      avgResponsePartner: avgResponsePartner.toDouble(),
      avgMessageLengthMe: avgLengthMe.toDouble(),
      avgMessageLengthPartner: avgLengthPartner.toDouble(),
      initiationRatioMe: initiationRatioMe.toDouble(),
      dailyCount: dailyCount,
      responsiveness: responsiveness,
      consistency: consistency,
      effortBalance: effortBalance,
      engagement: engagement,
      stability: stability,
    );
  }

  double _scoreResponsiveness(double me, double partner) {
    final avg = (me + partner) / 2;
    if (avg == 0) return 50;
    final score = 100 - (avg.clamp(0, 120)); // makin lama makin turun
    return score.clamp(0, 100).toDouble();
  }

  double _scoreConsistency(Map<String, int> dailyCount) {
    if (dailyCount.isEmpty) return 50;

    final values = dailyCount.values.toList();
    final avg = values.reduce((a, b) => a + b) / values.length;

    double variance = 0;
    for (var v in values) {
      variance += (v - avg) * (v - avg);
    }

    variance /= values.length;

    final score = 100 - variance;
    return score.clamp(0, 100);
  }

  double _scoreEffortBalance(int me, int partner, double initiationRatio) {
    if (me + partner == 0) return 50;

    final diff = (me - partner).abs() / (me + partner);
    final balanceScore = 100 - (diff * 100);

    final initiationScore = 100 - ((initiationRatio - 0.5).abs() * 200);

    return ((balanceScore + initiationScore) / 2).clamp(0, 100);
  }

  double _scoreEngagement(double lenMe, double lenPartner) {
    final avg = (lenMe + lenPartner) / 2;
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

    final score = 100 - fluctuation;
    return score.clamp(0, 100);
  }
}
