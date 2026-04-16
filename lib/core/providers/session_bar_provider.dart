import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data displayed in the persistent session bar (mini-player pattern).
class SessionBarData {
  final String dayStr;         // "Mardi 14 avril"
  final String timeRangeStr;   // "de 14:52 à 14:52"
  final String durationStr;    // "00:00:12"
  final String amountStr;      // "0,27 €"
  final String? clientId;
  final String? projectId;
  final String? sessionId;

  const SessionBarData({
    required this.dayStr,
    required this.timeRangeStr,
    required this.durationStr,
    required this.amountStr,
    this.clientId,
    this.projectId,
    this.sessionId,
  });
}

/// null = bar hidden, non-null = bar visible with session data.
final sessionBarProvider = StateProvider<SessionBarData?>((ref) => null);
