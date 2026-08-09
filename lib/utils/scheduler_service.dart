import 'dart:async';
import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Per-character scheduler status from the xiaoya bridge.
class SchedulerCharInfo {
  final String character;
  final String nextCst;        // e.g. "14:35"
  final double remainingMin;   // e.g. 23.7
  final int consecutive;
  final int maxConsecutive;
  final String lastResetCst;

  SchedulerCharInfo({
    required this.character,
    required this.nextCst,
    required this.remainingMin,
    required this.consecutive,
    required this.maxConsecutive,
    required this.lastResetCst,
  });

  factory SchedulerCharInfo.fromJson(Map<String, dynamic> json) {
    return SchedulerCharInfo(
      character: json['character'] as String? ?? '',
      nextCst: json['next_cst'] as String? ?? '--',
      remainingMin: (json['remaining_min'] as num?)?.toDouble() ?? 0,
      consecutive: (json['consecutive'] as num?)?.toInt() ?? 0,
      maxConsecutive: (json['max'] as num?)?.toInt() ?? 10,
      lastResetCst: json['last_reset_cst'] as String? ?? '--',
    );
  }

  /// Whether this character can still send proactive messages.
  bool get isActive => consecutive < maxConsecutive;

  /// Human-readable remaining time.
  String get remainingText {
    if (!isActive) return '等待回复';
    if (remainingMin <= 0) return '即将';
    if (remainingMin < 1) return '<1分钟';
    if (remainingMin < 60) return '${remainingMin.round()}分钟';
    final h = (remainingMin / 60).floor();
    final m = (remainingMin.round() % 60);
    return '${h}h${m > 0 ? '${m}m' : ''}';
  }
}

/// Polls the xiaoya bridge /scheduler/status endpoint periodically.
class SchedulerService {
  static final SchedulerService instance = SchedulerService._();
  SchedulerService._();

  final ValueNotifier<Map<String, SchedulerCharInfo>> status =
      ValueNotifier<Map<String, SchedulerCharInfo>>({});

  Timer? _timer;
  String? _lastUrl;

  void start() {
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetch());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetch() async {
    final url = AppSettings.schedulerApiUrl.value;
    if (url.isEmpty) return;
    _lastUrl = url;

    try {
      final resp = await http
          .get(Uri.parse('$url/scheduler/status'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final chars = (data['chars'] as List?) ?? [];

      final map = <String, SchedulerCharInfo>{};
      for (final c in chars) {
        final info = SchedulerCharInfo.fromJson(c as Map<String, dynamic>);
        map[info.character] = info;
      }
      status.value = map;
    } catch (_) {
      // bridge unreachable — silently ignore
    }
  }
}
