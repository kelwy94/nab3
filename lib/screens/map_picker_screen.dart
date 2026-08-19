import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    // Default to a central location in Egypt if no initial location is provided
    _currentCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357); // Cairo
  }

  void _zoomIn() {
    _mapController.move(_currentCenter, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_currentCenter, _mapController.camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع', style: TextStyle(color: NabaTheme.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: NabaTheme.primary),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 13.0,
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  setState(() {
                    _currentCenter = position.center!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite 
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nab3.app',
              ),
            ],
          ),
          // Center Marker
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Adjust to point the bottom of the icon to the center
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 50,
              ),
            ),
          ),
          // Controls
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'map_type',
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                    color: NabaTheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSatellite = !_isSatellite;
                    });
                  },
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded, color: NabaTheme.primary),
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove_rounded, color: NabaTheme.primary),
                  onPressed: _zoomOut,
                ),
              ],
            ),
          ),
          // Bottom button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context, _currentCenter);
              },
              child: const Text('تأكيد الموقع', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
