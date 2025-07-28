import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracking_app/views/saved_addresses_screen.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _initialPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 10,
  );

  final Set<Marker> _markers = {};
  GoogleMapController? _controller;
  LatLng? _myLatLng;
  bool _loadingLocation = true;

  final TextEditingController _addressCtrl = TextEditingController();
  final _uuid = const Uuid();
  String? _sessionToken;
  String _label = 'Home';
  final List<dynamic> _labels = const [
  ['Home', Icons.home],
  ['Office', Icons.work_outline],
  ['Other', Icons.location_on],
  ];

  static const _kPlacesKey = 'AIzaSyA_y9vj72CfDEcWI2WSXOkYtDkwbPQpPp0';

  @override
  void initState() {
    super.initState();
    _initLocation();
    _sessionToken = _uuid.v4();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() => _loadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _loadingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _myLatLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('me'),
            position: _myLatLng!,
            infoWindow: const InfoWindow(title: 'You are here'),
          ),
        );
        _loadingLocation = false;
      });

      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _myLatLng!, zoom: 16),
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() => _loadingLocation = false);
    }
  }
  Future<List<PlaceSuggestion>> _getSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    _sessionToken ??= _uuid.v4();

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': pattern,
        'key': _kPlacesKey,
        'sessiontoken': _sessionToken!,
        'language': 'en',
        // Remove this line ↓ so "Pakistan" can match
        // 'types': 'address',
        // If you only want PK results, uncomment:
        // 'components': 'country:pk',
      },
    );

    try {
      // debugPrint('Calling Places: $uri');
      final res = await http.get(uri);
      // debugPrint('Status: ${res.statusCode}');
      // debugPrint('Body: ${res.body}');

      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      final status = data['status'];
      if (status != 'OK') {
        debugPrint('Places error: $status | ${data['error_message']}');
        return [];
      }

      return (data['predictions'] as List)
          .map((e) => PlaceSuggestion(
        placeId: e['place_id'],
        description: e['description'],
      ))
          .toList();
    } catch (e, st) {
      debugPrint('Autocomplete error: $e\n$st');
      return [];
    }
  }

  Future<LatLng?> _getLatLngFromPlaceId(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry,formatted_address',
        'key': _kPlacesKey,
        'sessiontoken': _sessionToken ?? _uuid.v4(),
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body);
    final loc = data['result']?['geometry']?['location'];
    final formattedAddress = data['result']?['formatted_address'];
    if (formattedAddress != null) {
      _addressCtrl.text = formattedAddress;
    }
    if (loc == null) return null;
    return LatLng(loc['lat'] * 1.0, loc['lng'] * 1.0);
  }

  void _onSavePressed() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty || _markers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select and name the address')),
      );
      return;
    }

    // Get coordinates from selected marker (not 'me')
    final selectedMarker = _markers.firstWhere(
          (m) => m.markerId == const MarkerId('selected'),
      orElse: () => Marker(markerId: const MarkerId('none')),
    );

    if (selectedMarker.markerId.value == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location selected')),
      );
      return;
    }

    final locationData = {
      'label': _label,
      'address': address,
      'latitude': selectedMarker.position.latitude,
      'longitude': selectedMarker.position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous', // Or replace with your user id logic
    };

    await FirebaseFirestore.instance.collection('saved_addresses').add(locationData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $_label address successfully!')),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.red),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Saved Addresses'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SavedAddressesScreen(),
                ));
              },
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (c) => _controller = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
          ),
          if (_loadingLocation)
            const Center(child: CircularProgressIndicator()),

          // Draggable bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.4, // start at 40% of screen
            minChildSize: 0.1,     // can drag down to 10%
            maxChildSize: 0.8,     // can drag up to 80%
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text("Select Location",style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold),),
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const Text(
                        'Your Location',
                        style: TextStyle(
                            fontSize: 12,color: Color(0xff9D9D9D)),
                      ),
                      const SizedBox(height: 8),
                      TypeAheadField<PlaceSuggestion>(
                        debounceDuration: const Duration(milliseconds: 300),
                        suggestionsCallback: (pattern) async {
                          if (pattern.isEmpty) return [];
                          return _getSuggestions(pattern);
                        },
                        controller: _addressCtrl, // Use your controller directly
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Enter your Address',
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                        itemBuilder: (context, suggestion) => ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(suggestion.description),
                        ),
                        onSelected: (suggestion) async {
                          _addressCtrl.text = suggestion.description; // Set selected address
                          final latLng = await _getLatLngFromPlaceId(suggestion.placeId);
                          if (latLng != null) {
                            setState(() {
                              _markers.removeWhere((m) => m.markerId == const MarkerId('selected'));
                              _markers.add(Marker(
                                markerId: const MarkerId('selected'),
                                position: latLng,
                                infoWindow: InfoWindow(title: suggestion.description),
                              ));
                            });
                            _controller?.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(target: latLng, zoom: 16),
                              ),
                            );
                          }
                        },
                        loadingBuilder: (context) => const SizedBox.shrink(),
                        emptyBuilder: (context) => const SizedBox.shrink(),
                        transitionBuilder: (context, animation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Save as',
                          style: TextStyle(
                              fontSize: 12,color: Color(0xff9D9D9D))),
                      const SizedBox(height: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _labels.take(2).map((label) {
                              final selected = _label == label[0];
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 5,right: 5),
                                  child: ChoiceChip(
                                    selected: selected,
                                    onSelected: (_) => setState(() => _label = label[0]),
                                    selectedColor: Colors.green,
                                    backgroundColor: const Color(0xFFF5F5F5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    showCheckmark: true,
                                    checkmarkColor: Colors.white,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    pressElevation: 0,
                                    shadowColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    label: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xffffeaea),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            label[1] as IconData,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          label[0],
                                          style: TextStyle(
                                            color: selected ? Colors.white : Colors.black,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 10),
                          Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.45, // ✅ Half screen width
                                child: ChoiceChip(
                                  selected: _label == _labels[2][0],
                                  onSelected: (_) => setState(() => _label = _labels[2][0]),
                                  selectedColor: Colors.green,
                                  backgroundColor: const Color(0xFFF5F5F5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: true,
                                  checkmarkColor: Colors.white,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  pressElevation: 0,
                                  shadowColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  label: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xffffeaea),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _labels[2][1] as IconData,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _labels[2][0],
                                        style: TextStyle(
                                          color: _label == _labels[2][0] ? Colors.white : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),

                      const SizedBox(height: 70),
                      SizedBox(
                        width: double.infinity,
                        height: 50, // ✅ Set height here
                        child: ElevatedButton(
                          onPressed: _onSavePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // ✅ Red background
                            foregroundColor: Colors.white, // ✅ Optional: white text
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
                            ),
                            elevation: 0, // Optional: remove shadow
                          ),
                          child: const Text(
                            'Save Address',
                            style: TextStyle(fontSize: 16), // Optional: custom font size
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  PlaceSuggestion({required this.placeId, required this.description});
}
