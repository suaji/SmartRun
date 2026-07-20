import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/dummy_data.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/history_repository.dart';
import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/lane_bar.dart';
import '../widgets/profile_avatar.dart';

enum _RunState { idle, running, paused }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _RunState _state = _RunState.idle;
  WorkoutMode _selectedMode = WorkoutMode.interval;
  IntervalTemplate _template = DummyData.todayTemplate;
  int _segmentIndex = 0;
  int _remainingSeconds = 0;

  double _selectedDistanceKm = 5;
  int _distanceSegmentIndex = 0;
  double _segmentStartMeters = 0;
  int _lastAnnouncedKm = 0;

  bool get _isDistanceTarget => _selectedMode == WorkoutMode.distanceTarget;

  DistanceTemplate get _selectedDistanceTemplate => DummyData.distanceTemplates
      .firstWhere((t) => t.totalKm == _selectedDistanceKm);

  int _elapsedSeconds = 0;
  Timer? _ticker;
  Timer? _endHoldTimer;
  bool _endHoldFired = false;
  DateTime? _runStartTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartedAt;

  // GPS
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  double _distanceMeters = 0;
  String? _gpsError = 'Checking GPS...';
  LatLng? _currentLatLng;
  final List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _startGps();
    _recoverAbandonedCheckpoint();
  }

  Future<void> _recoverAbandonedCheckpoint() async {
    final checkpoint = await HistoryRepository.loadCheckpoint();
    if (checkpoint == null) return;
    if (checkpoint.distanceKm >= 0.05) {
      await HistoryRepository.addRun(checkpoint);
      if (mounted) {
        AppStateScope.of(context).bumpHistoryVersion();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Recovered a run that didn\'t finish cleanly (${checkpoint.distanceKm.toStringAsFixed(2)}km saved to History).'),
        ));
      }
    }
    await HistoryRepository.clearCheckpoint();
  }

  bool get _isInterval => _selectedMode == WorkoutMode.interval;

  int _secondsFor(LaneSegment segment) => (segment.weight * 60).round();

  double get _distanceKm => _distanceMeters / 1000;

  String get _paceLabel {
    if (_distanceKm < 0.05) return '--';
    final secondsPerKm = _elapsedSeconds / _distanceKm;
    final minutes = (secondsPerKm ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsPerKm.round() % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _selectMode(WorkoutMode mode) {
    if (_state != _RunState.idle) return;
    setState(() => _selectedMode = mode);
  }

  void _startRun() {
    if (_state != _RunState.idle) return;
    HapticFeedback.mediumImpact();
    WakelockPlus.enable();
    if (_isInterval) {
      _template = AppStateScope.of(context).selectedTemplate;
    }
    setState(() {
      _state = _RunState.running;
      _segmentIndex = 0;
      _distanceSegmentIndex = 0;
      _segmentStartMeters = 0;
      _lastAnnouncedKm = 0;
      _elapsedSeconds = 0;
      _distanceMeters = 0;
      _lastPosition = null;
      _routePoints.clear();
      _runStartTime = DateTime.now();
      _pausedDuration = Duration.zero;
      _pauseStartedAt = null;
      if (_isInterval) {
        _remainingSeconds = _secondsFor(_template.segments.first);
      }
    });
    if (_isInterval) {
      _announcePhase(_template.segments.first.type);
    } else if (_isDistanceTarget) {
      _announcePhase(_selectedDistanceTemplate.segments.first.type);
    } else {
      TtsService.speak('Go, run');
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _announcePhase(SegmentType type) {
    if (type == SegmentType.work) {
      HapticService.runCue();
    } else {
      HapticService.walkCue();
    }
    TtsService.speak(type == SegmentType.work ? 'Go, run' : 'Walk');
  }

  void _maybeAnnounceDistance() {
    final wholeKm = _distanceKm.floor();
    if (wholeKm >= 1 && wholeKm > _lastAnnouncedKm) {
      _lastAnnouncedKm = wholeKm;
      TtsService.speak('$wholeKm kilometer${wholeKm == 1 ? '' : 's'}');
    }
  }

  Future<void> _startGps() async {
    if (_positionSub != null) return;
    final error = await LocationService.ensurePermission();
    if (!mounted) return;
    if (error != null) {
      setState(() => _gpsError = error);
      return;
    }
    setState(() => _gpsError = null);
    _positionSub = LocationService.positionStream().listen(_onNewPosition);
  }

  void _onNewPosition(Position position) {
    if (_lastPosition != null && _state == _RunState.running) {
      _distanceMeters +=
          LocationService.distanceBetween(_lastPosition!, position);
    }
    _lastPosition = position;
    _currentLatLng = LatLng(position.latitude, position.longitude);
    if (_state == _RunState.running) {
      _routePoints.add(_currentLatLng!);
    }
    if (mounted) {
      setState(() {});
      try {
        _mapController.move(_currentLatLng!, _mapController.camera.zoom);
      } catch (_) {
        // Map not attached yet on the very first fix - fine, initialCenter handles it.
      }
    }
  }

  void _saveCheckpoint() {
    final modeLabel = _isDistanceTarget
        ? 'Distance target (${_selectedDistanceTemplate.label})'
        : _selectedMode.label;
    HistoryRepository.saveCheckpoint(RunRecord(
      modeLabel: '$modeLabel (recovered)',
      distanceKm: _distanceKm,
      elapsedSeconds: _elapsedSeconds,
      pace: _paceLabel,
      date: _runStartTime ?? DateTime.now(),
      route: List<LatLng>.from(_routePoints),
    ));
  }

  void _tick() {
    if (_state != _RunState.running) return;
    setState(() {
      if (_runStartTime != null) {
        final rawElapsed = DateTime.now().difference(_runStartTime!).inSeconds;
        _elapsedSeconds = (rawElapsed - _pausedDuration.inSeconds).clamp(0, 1 << 31);
      }
      if (_isInterval) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _advanceSegment();
        }
      } else if (_isDistanceTarget) {
        final segment = _selectedDistanceTemplate.segments[_distanceSegmentIndex];
        if (_distanceMeters - _segmentStartMeters >= segment.meters) {
          _advanceDistanceSegment();
        }
      }
      _maybeAnnounceDistance();
      if (_elapsedSeconds > 0 && _elapsedSeconds % 60 == 0) {
        _saveCheckpoint();
      }
    });
  }

  void _advanceSegment() {
    final nextIndex = _segmentIndex + 1;
    if (nextIndex >= _template.segments.length) {
      _finishRun();
      return;
    }
    _segmentIndex = nextIndex;
    _remainingSeconds = _secondsFor(_template.segments[_segmentIndex]);
    _announcePhase(_template.segments[_segmentIndex].type);
  }

  void _advanceDistanceSegment() {
    final segments = _selectedDistanceTemplate.segments;
    final nextIndex = _distanceSegmentIndex + 1;
    if (nextIndex >= segments.length) {
      _finishRun();
      return;
    }
    _distanceSegmentIndex = nextIndex;
    _segmentStartMeters = _distanceMeters;
    _announcePhase(segments[_distanceSegmentIndex].type);
  }

  void _togglePause() {
    setState(() {
      if (_state == _RunState.running) {
        _state = _RunState.paused;
        _pauseStartedAt = DateTime.now();
      } else {
        if (_pauseStartedAt != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
          _pauseStartedAt = null;
        }
        _state = _RunState.running;
      }
    });
  }

  void _finishRun() {
    WakelockPlus.disable();
    HapticService.finishCue();
    TtsService.speak('Workout complete. Great job.');
    _ticker?.cancel();
    _positionSub?.cancel();
    HistoryRepository.clearCheckpoint();
    final modeLabel = _isDistanceTarget
        ? 'Distance target (${_selectedDistanceTemplate.label})'
        : _selectedMode.label;
    final distance = _distanceKm;
    final elapsed = _elapsedSeconds;
    final pace = _paceLabel;
    final route = List<LatLng>.from(_routePoints);
    setState(() {
      _state = _RunState.idle;
      _elapsedSeconds = 0;
      _distanceMeters = 0;
      _segmentIndex = 0;
      _distanceSegmentIndex = 0;
      _segmentStartMeters = 0;
      _lastAnnouncedKm = 0;
      _routePoints.clear();
      _runStartTime = null;
      _pausedDuration = Duration.zero;
      _pauseStartedAt = null;
    });

    if (distance >= 0.05) {
      final appState = AppStateScope.of(context);
      HistoryRepository.addRun(RunRecord(
        modeLabel: modeLabel,
        distanceKm: distance,
        elapsedSeconds: elapsed,
        pace: pace,
        date: DateTime.now(),
        route: route,
      )).then((_) {
        if (mounted) appState.bumpHistoryVersion();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/summary', arguments: {
        'modeLabel': modeLabel,
        'distanceKm': distance,
        'elapsedSeconds': elapsed,
        'pace': pace,
        'route': route,
      });
    });
  }

  void _confirmEndRun() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surfaceElevated,
        title: Text('End this run?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text('Your progress so far will be saved to the summary.',
            style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep going')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _finishRun();
            },
            child: const Text('End run'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _endHoldTimer?.cancel();
    _positionSub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _state != _RunState.idle;
    final isWork = running &&
        (_isInterval
            ? _template.segments[_segmentIndex].type == SegmentType.work
            : _isDistanceTarget
                ? _selectedDistanceTemplate.segments[_distanceSegmentIndex].type == SegmentType.work
                : true);
    final dialColor = !running
        ? context.colors.accent
        : (_isInterval || _isDistanceTarget)
            ? (isWork ? context.colors.work : context.colors.rest)
            : context.colors.accent;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: 'SmartRun ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                    TextSpan(text: 'by Ajie.AI', style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
                  ]),
                ),
                const ProfileAvatar(size: 50),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_gpsError == null ? 'GPS connected' : 'GPS unavailable',
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
            ),
            if (_gpsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_gpsError!, style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
              ),
            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 260,
                child: _currentLatLng == null
                    ? Container(
                        color: context.colors.surface,
                        alignment: Alignment.center,
                        child: Text('Locating...', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLatLng!,
                          initialZoom: 16,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: context.mapTileUrl,
                            subdomains: context.mapTileSubdomains,
                            userAgentPackageName: 'com.suaji.smartrun',
                          ),
                          if (_routePoints.length > 1)
                            PolylineLayer(polylines: [
                              Polyline(points: _routePoints, strokeWidth: 3, color: context.colors.accent),
                            ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: _currentLatLng!,
                              width: 16, height: 16,
                              child: Container(
                                decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              ),
                            ),
                          ]),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _StatCard(value: '${_distanceKm.toStringAsFixed(2)} km', label: 'Distance')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(value: _formatSeconds(_elapsedSeconds), label: 'Time')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(value: '$_paceLabel/km', label: 'Avg pace')),
              ],
            ),
            const SizedBox(height: 8),

            if (_isInterval && running) ...[
              LaneBar(segments: _template.segments, height: 6, currentIndex: _segmentIndex),
              const SizedBox(height: 4),
              Center(
                child: Text('Set ${_currentWorkSetNumber()} / $_totalWorkSets',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              ),
            ],
            if (_isDistanceTarget && running) ...[
              LaneBar(segments: _distanceLaneSegments, height: 6, currentIndex: _distanceSegmentIndex),
              const SizedBox(height: 4),
              Center(
                child: Text('Leg ${_currentDistanceLegNumber()} / $_totalDistanceLegs',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              ),
            ],

            Center(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    _bigDialText(running),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: dialColor, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 10),
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) {
                      if (_state == _RunState.idle) {
                        HapticFeedback.selectionClick();
                      } else {
                        _endHoldFired = false;
                        _endHoldTimer = Timer(const Duration(milliseconds: 600), () {
                          _endHoldFired = true;
                          HapticFeedback.heavyImpact();
                          _confirmEndRun();
                        });
                      }
                    },
                    onPointerUp: (_) {
                      if (_state == _RunState.idle) {
                        _startRun();
                      } else {
                        _endHoldTimer?.cancel();
                        if (!_endHoldFired) {
                          _togglePause();
                        }
                        _endHoldFired = false;
                      }
                    },
                    onPointerCancel: (_) {
                      _endHoldTimer?.cancel();
                      _endHoldFired = false;
                    },
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dialColor, width: 2)),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _state == _RunState.idle
                                ? 'START'
                                : (_state == _RunState.paused
                                    ? 'Paused'
                                    : ((_isInterval || _isDistanceTarget) ? (isWork ? 'Run' : 'Walk') : 'Running')),
                            style: TextStyle(color: dialColor, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _state == _RunState.idle
                                ? 'Tap to start'
                                : 'Tap: ${_state == _RunState.paused ? 'resume' : 'pause'} · Hold: end',
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            if (!running) ...[
              Text('Workout modes', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: WorkoutMode.values.map((mode) {
                  final selected = mode == _selectedMode;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectMode(mode),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? context.colors.accent : Colors.transparent, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(_iconFor(mode), size: 20, color: selected ? context.colors.accent : context.colors.textSecondary),
                            const SizedBox(height: 4),
                            Text(mode.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                            Text(mode.subtitle, style: TextStyle(fontSize: 9, color: context.colors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedMode == WorkoutMode.interval) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_outlined, size: 16, color: context.colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Using: ${AppStateScope.of(context).selectedTemplate.name}',
                          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => AppStateScope.of(context).requestTab(1),
                        child: Text('Change in Plans', style: TextStyle(fontSize: 11, color: context.colors.accent, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedMode == WorkoutMode.distanceTarget) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DummyData.distanceTemplates.map((t) {
                    final selected = t.totalKm == _selectedDistanceKm;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDistanceKm = t.totalKm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? context.colors.accent : Colors.transparent, width: 1.5),
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? context.colors.accent : context.colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WorkoutMode mode) => switch (mode) {
        WorkoutMode.easyRun => Icons.schedule,
        WorkoutMode.interval => Icons.favorite_border,
        WorkoutMode.distanceTarget => Icons.track_changes,
      };

  int get _totalWorkSets => _template.segments.where((s) => s.type == SegmentType.work).length;

  int _currentWorkSetNumber() {
    var count = 0;
    for (var i = 0; i <= _segmentIndex && i < _template.segments.length; i++) {
      if (_template.segments[i].type == SegmentType.work) count++;
    }
    return count.clamp(1, _totalWorkSets);
  }

  List<LaneSegment> get _distanceLaneSegments => _selectedDistanceTemplate.segments
      .map((s) => LaneSegment(s.type, s.meters))
      .toList();

  int get _totalDistanceLegs =>
      _selectedDistanceTemplate.segments.where((s) => s.type == SegmentType.work).length;

  int _currentDistanceLegNumber() {
    var count = 0;
    final segments = _selectedDistanceTemplate.segments;
    for (var i = 0; i <= _distanceSegmentIndex && i < segments.length; i++) {
      if (segments[i].type == SegmentType.work) count++;
    }
    return count.clamp(1, _totalDistanceLegs);
  }

  String _bigDialText(bool running) {
    if (!running) return '00:00';
    if (_isInterval) return _formatSeconds(_remainingSeconds);
    if (_isDistanceTarget) {
      final segment = _selectedDistanceTemplate.segments[_distanceSegmentIndex];
      final remaining = (segment.meters - (_distanceMeters - _segmentStartMeters))
          .clamp(0, segment.meters);
      return remaining >= 1000
          ? '${(remaining / 1000).toStringAsFixed(2)}km'
          : '${remaining.round()}m';
    }
    return _formatSeconds(_elapsedSeconds);
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 10, color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}
