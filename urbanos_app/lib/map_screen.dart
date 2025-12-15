import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'wallet_screen.dart'; // <--- ¡ESTA ERA LA LÍNEA QUE FALTABA!

class BusEntity {
  String id;
  LatLng currentLocation;
  LatLng targetLocation;

  BusEntity({required this.id, required this.currentLocation, required this.targetLocation});
}

class MapScreen extends StatefulWidget {
  // Recibimos el ID del usuario desde el Login
  final String userId; 
  const MapScreen({super.key, required this.userId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Map<String, BusEntity> _activeBuses = {};
  Timer? _fetchTimer;
  Timer? _animationTimer;
  
  bool _isDriverMode = false;
  StreamSubscription<Position>? _gpsStream;
  
  // Si estoy en modo conductor, uso mi propio ID de usuario como ID del bus
  String get _myBusId => widget.userId; // Usamos los primeros 3 caracteres del ID como "Placa"

  @override
  void initState() {
    super.initState();
    _fetchBuses();
    _fetchTimer = Timer.periodic(const Duration(seconds: 2), (timer) => _fetchBuses());
    _animationTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) => _animateBuses());
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    _animationTimer?.cancel();
    _gpsStream?.cancel();
    super.dispose();
  }

  Future<void> _toggleDriverMode() async {
    if (_isDriverMode) {
      await _gpsStream?.cancel();
      setState(() => _isDriverMode = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🛑 Modo Conductor Apagado')));
    } else {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      setState(() => _isDriverMode = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🟢 ¡Eres el Bus $_myBusId! Transmitiendo...')));

      const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      _gpsStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
        _sendMyLocation(position);
      });
    }
  }

  Future<void> _sendMyLocation(Position position) async {
    try {
      final url = Uri.parse('https://urbanos-api.onrender.com/buses/$_myBusId/location');
      await http.put(url, 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lat": position.latitude,
          "lng": position.longitude
        })
      );
    } catch (e) {
      print("Error enviando GPS: $e");
    }
  }

  Future<void> _fetchBuses() async {
    try {
      final response = await http.get(Uri.parse('https://urbanos-api.onrender.com/buses'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var busData in data) {
          String busId = busData['id'];
          double newLat = double.parse(busData['last_latitude'].toString());
          double newLng = double.parse(busData['last_longitude'].toString());
          LatLng newTarget = LatLng(newLat, newLng);

          if (_activeBuses.containsKey(busId)) {
            _activeBuses[busId]!.targetLocation = newTarget;
          } else {
            _activeBuses[busId] = BusEntity(id: busId, currentLocation: newTarget, targetLocation: newTarget);
          }
        }
        setState(() {});
      }
    } catch (e) { print(e); }
  }

  void _animateBuses() {
    bool needsRepaint = false;
    _activeBuses.forEach((id, bus) {
      double distLat = bus.targetLocation.latitude - bus.currentLocation.latitude;
      double distLng = bus.targetLocation.longitude - bus.currentLocation.longitude;
      if (distLat.abs() > 0.00001 || distLng.abs() > 0.00001) {
        bus.currentLocation = LatLng(bus.currentLocation.latitude + (distLat * 0.1), bus.currentLocation.longitude + (distLng * 0.1));
        needsRepaint = true;
      }
    });
    if (needsRepaint) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isDriverMode ? 'MODO CONDUCTOR ($_myBusId)' : 'Urbanos Pereira', style: const TextStyle(color: Colors.white)),
        backgroundColor: _isDriverMode ? Colors.red : const Color(0xFFFF6600),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: const LatLng(4.8142, -75.6961), initialZoom: 15.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.urbanos.app'),
              MarkerLayer(
                markers: _activeBuses.values.map((bus) {
                  return Marker(
                    point: bus.currentLocation,
                    width: 60, height: 60,
                    child: const Icon(Icons.directions_bus, color: Color(0xFFFF6600), size: 40),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // BOTÓN DE BILLETERA (Izquierda)
          Positioned(
            bottom: 30, left: 20,
            child: FloatingActionButton(
              heroTag: "btnWallet",
              onPressed: () {
                // Ahora sí funciona porque importamos wallet_screen.dart arriba
                Navigator.push(context, MaterialPageRoute(builder: (context) => WalletScreen(userId: widget.userId)));
              },
              backgroundColor: Colors.purple,
              child: const Icon(Icons.wallet, color: Colors.white),
            ),
          ),

          // BOTÓN MODO CONDUCTOR (Derecha)
          Positioned(
            bottom: 30, right: 20,
            child: FloatingActionButton.extended(
              heroTag: "btnDriver",
              onPressed: _toggleDriverMode,
              backgroundColor: _isDriverMode ? Colors.red : Colors.green,
              icon: Icon(_isDriverMode ? Icons.stop : Icons.navigation, color: Colors.white),
              label: Text(_isDriverMode ? "Detener" : "Soy Conductor", style: const TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}