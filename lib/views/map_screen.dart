import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  final LatLng start;
  final LatLng end;

  const MapScreen({super.key, required this.start, required this.end});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  bool _isDark = false;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.red,
        width: 5,
        points: [widget.start, widget.end],
      ),
    };
  }

  Future<void> _setMapStyle(bool dark) async {
    final stylePath = dark
        ? 'assets/map_style_dark.json'
        : 'assets/map_style_light.json';

    final styleJson = await rootBundle.loadString(stylePath);
    _mapController.setMapStyle(styleJson);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setMapStyle(_isDark); // Initial style
  }

  @override
  Widget build(BuildContext context) {
    final midPoint = LatLng(
      (widget.start.latitude + widget.end.latitude) / 2,
      (widget.start.longitude + widget.end.longitude) / 2,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: _isDark ? Colors.white : Colors.black, // This is now valid
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),

        actions: [
          IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _isDark = !_isDark;
                _setMapStyle(_isDark);
              });
            },
          )
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: midPoint,
          zoom: 12,
        ),
        markers: {
          Marker(markerId: const MarkerId('start'), position: widget.start),
          Marker(markerId: const MarkerId('end'), position: widget.end),
        },
        polylines: _polylines,
      ),
    );
  }
}
