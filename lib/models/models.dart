import 'package:latlong2/latlong.dart';

enum SegmentType { work, rest }

class LaneSegment {
  final SegmentType type;
  final double weight;
  const LaneSegment(this.type, this.weight);
}

class IntervalTemplate {
  final String name;
  final String meta;
  final List<LaneSegment> segments;
  const IntervalTemplate({
    required this.name,
    required this.meta,
    required this.segments,
  });
}

class WeekPlan {
  final int week;
  final String phaseLabel;
  final bool isCutback;
  final IntervalTemplate sessionA;
  final double sessionBKm;
  final double sessionCKm;
  const WeekPlan({
    required this.week,
    required this.phaseLabel,
    required this.isCutback,
    required this.sessionA,
    required this.sessionBKm,
    required this.sessionCKm,
  });
}

enum WorkoutMode { easyRun, interval, distanceTarget }

extension WorkoutModeLabel on WorkoutMode {
  String get label => switch (this) {
        WorkoutMode.easyRun => 'Easy run',
        WorkoutMode.interval => 'Interval training',
        WorkoutMode.distanceTarget => 'Distance target',
      };

  String get subtitle => switch (this) {
        WorkoutMode.easyRun => '30min target',
        WorkoutMode.interval => 'Stamina goal',
        WorkoutMode.distanceTarget => 'Voice-guided run/walk',
      };
}

class DistanceSegment {
  final SegmentType type;
  final double meters;
  const DistanceSegment(this.type, this.meters);
}

class DistanceTemplate {
  final double totalKm;
  final String label;
  final List<DistanceSegment> segments;
  const DistanceTemplate({
    required this.totalKm,
    required this.label,
    required this.segments,
  });
}

class RunRecord {
  final String modeLabel;
  final double distanceKm;
  final int elapsedSeconds;
  final String pace;
  final DateTime date;
  final List<LatLng> route;

  const RunRecord({
    required this.modeLabel,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.pace,
    required this.date,
    this.route = const [],
  });

  Map<String, dynamic> toJson() => {
        'modeLabel': modeLabel,
        'distanceKm': distanceKm,
        'elapsedSeconds': elapsedSeconds,
        'pace': pace,
        'date': date.toIso8601String(),
        'route': route.map((p) => [p.latitude, p.longitude]).toList(),
      };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
        modeLabel: json['modeLabel'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        elapsedSeconds: json['elapsedSeconds'] as int,
        pace: json['pace'] as String,
        date: DateTime.parse(json['date'] as String),
        route: (json['route'] as List? ?? const [])
            .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
      );
}

class SplitResult {
  final String label;
  final String pace;
  const SplitResult({required this.label, required this.pace});
}

class AchievementBadge {
  final String title;
  final String description;
  final String icon;
  final bool earned;
  const AchievementBadge({
    required this.title,
    required this.description,
    required this.icon,
    required this.earned,
  });
}
