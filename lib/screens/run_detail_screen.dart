import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/calorie_calculator.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RunDetailScreen extends StatelessWidget {
  final RunRecord record;
  const RunDetailScreen({super.key, required this.record});

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final route = record.route;
    final calories = CalorieCalculator.estimate(
      weightKg: AppStateScope.of(context).weightKg,
      distanceKm: record.distanceKm,
    );

    return Scaffold(
      appBar: AppBar(title: Text(record.modeLabel), backgroundColor: context.colors.background),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_formatDate(record.date), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: route.length < 2
                    ? Container(
                        color: context.colors.surface,
                        alignment: Alignment.center,
                        child: Text('No route data was saved for this run',
                            style: TextStyle(color: context.colors.textSecondary)),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(coordinates: route, padding: const EdgeInsets.all(24)),
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: context.mapTileUrl,
                            subdomains: context.mapTileSubdomains,
                            userAgentPackageName: 'com.suaji.smartrun',
                          ),
                          PolylineLayer(polylines: [
                            Polyline(points: route, strokeWidth: 4, color: context.colors.accent),
                          ]),
                          MarkerLayer(markers: [
                            Marker(point: route.first, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle))),
                            Marker(point: route.last, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: context.colors.work, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                          ]),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _MetricTile(label: 'Distance', value: '${record.distanceKm.toStringAsFixed(2)} km'),
                _MetricTile(label: 'Avg pace', value: '${record.pace} /km'),
                _MetricTile(label: 'Time', value: _formatDuration(record.elapsedSeconds)),
                _MetricTile(label: 'Calories', value: '${calories.round()} kcal'),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Tip: use your phone\'s screenshot to share this page',
                style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
