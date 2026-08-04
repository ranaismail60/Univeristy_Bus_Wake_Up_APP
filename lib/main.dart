import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniBusApp());
}

class UniBusApp extends StatelessWidget {
  const UniBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAST Bus Wake-Up & Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const MainHomeScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------
class BusStop {
  final String name;
  final String time;
  final double lat;
  final double lng;

  BusStop({
    required this.name,
    required this.time,
    required this.lat,
    required this.lng,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      name: json['name'],
      time: json['time'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class BusRoute {
  final String routeId;
  final String name;
  final String driver;
  final String contact;
  final List<BusStop> stops;

  BusRoute({
    required this.routeId,
    required this.name,
    required this.driver,
    required this.contact,
    required this.stops,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    var list = json['stops'] as List;
    List<BusStop> stopList = list.map((i) => BusStop.fromJson(i)).toList();
    return BusRoute(
      routeId: json['route_id'],
      name: json['name'],
      driver: json['driver'] ?? 'N/A',
      contact: json['contact'] ?? 'N/A',
      stops: stopList,
    );
  }
}

class PeerStudent {
  final String name;
  final String routeId;
  final String stopName;
  final double lat;
  final double lng;
  final double speedKmH;
  final bool isInBus;
  final DateTime lastSeen;

  PeerStudent({
    required this.name,
    required this.routeId,
    required this.stopName,
    required this.lat,
    required this.lng,
    required this.speedKmH,
    required this.isInBus,
    required this.lastSeen,
  });
}

// -----------------------------------------------------------------------------
// MAIN HOME SCREEN
// -----------------------------------------------------------------------------
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  List<BusRoute> _routes = [];
  bool _isLoading = true;

  // Student Profile
  String _studentName = 'Student';
  BusRoute? _selectedRoute;
  BusStop? _selectedStop;
  double _alarmRadiusMeters = 500.0;
  bool _isRegistered = false;

  // Real-time GPS & Simulation
  double _currentLat = 31.4501;
  double _currentLng = 73.1350;
  double _currentSpeed = 0.0; // km/h
  double _distanceToStopMeters = 999999;
  bool _isAlarmTriggered = false;
  bool _isTrackingActive = false;

  // Simulated P2P Mesh Network (Wi-Fi Direct / BLE)
  List<PeerStudent> _nearbyPeers = [];
  Timer? _p2pTimer;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/routes_data.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      var routeList = data['routes'] as List;
      setState(() {
        _routes = routeList.map((r) => BusRoute.fromJson(r)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading route data: $e");
      setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // HAVERSINE FORMULA DISTANCE CALCULATION
  // ---------------------------------------------------------------------------
  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    double dLat = (lat2 - lat1) * (pi / 180.0);
    double dLon = (lon2 - lon1) * (pi / 180.0);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  void _startTracking() {
    setState(() {
      _isTrackingActive = true;
    });

    // Simulate GPS updates and distance calculations
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_selectedStop != null) {
        // Compute Haversine distance
        double dist = _calculateHaversineDistance(
            _currentLat, _currentLng, _selectedStop!.lat, _selectedStop!.lng);

        setState(() {
          _distanceToStopMeters = dist;
        });

        // Trigger Alarm if within radius
        if (dist <= _alarmRadiusMeters && !_isAlarmTriggered) {
          _triggerWakeUpAlarm();
        }
      }
    });

    // Start P2P Mesh Network broadcast listener
    _startOfflineP2PMesh();
  }

  void _triggerWakeUpAlarm() {
    setState(() {
      _isAlarmTriggered = true;
    });
    // Haptic vibration feedback
    HapticFeedback.vibrate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.alarm_on, color: Colors.white, size: 36),
            SizedBox(width: 10),
            Text('BUS STOP ALARM!'),
          ],
        ),
        content: Text(
          'Wake Up! You are within ${_distanceToStopMeters.round()}m of your target stop: ${_selectedStop?.name}.\nGet ready to exit the bus!',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _isAlarmTriggered = false);
            },
            child: const Text('DISMISS ALARM', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OFFLINE P2P MESH NETWORK (Wi-Fi Direct / Local Hotspot Broadcast)
  // ---------------------------------------------------------------------------
  void _startOfflineP2PMesh() {
    _p2pTimer?.cancel();
    _p2pTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_selectedRoute == null) return;

      // Simulate receiving P2P signals from nearby students on the SAME route
      List<PeerStudent> samplePeers = [
        PeerStudent(
          name: 'Ali Raza',
          routeId: _selectedRoute!.routeId,
          stopName: _selectedRoute!.stops.first.name,
          lat: _currentLat + 0.002,
          lng: _currentLng + 0.002,
          speedKmH: 35.0, // Moving at 35km/h -> In Bus!
          isInBus: true,
          lastSeen: DateTime.now(),
        ),
        PeerStudent(
          name: 'Usman Ghani',
          routeId: _selectedRoute!.routeId,
          stopName: _selectedRoute!.stops.first.name,
          lat: _currentLat + 0.0021,
          lng: _currentLng + 0.0022,
          speedKmH: 38.0, // Moving at 38km/h -> In Bus!
          isInBus: true,
          lastSeen: DateTime.now(),
        ),
        PeerStudent(
          name: 'Hamza Khan',
          routeId: _selectedRoute!.routeId,
          stopName: _selectedStop?.name ?? 'Main Gate',
          lat: _selectedStop?.lat ?? 31.45,
          lng: _selectedStop?.lng ?? 73.13,
          speedKmH: 0.5, // Stationary -> Waiting at stop
          isInBus: false,
          lastSeen: DateTime.now(),
        ),
      ];

      setState(() {
        _nearbyPeers = samplePeers;
      });
    });
  }

  @override
  void dispose() {
    _p2pTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAST CFD - Offline Bus Wakeup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showRegistrationDialog(),
          )
        ],
      ),
      body: !_isRegistered
          ? _buildRegistrationPrompt()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildDistanceTrackerCard(),
                  const SizedBox(height: 16),
                  _buildCrowdBusRadarCard(),
                  const SizedBox(height: 16),
                  _buildRouteStopsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildRegistrationPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_filled, size: 80, color: Colors.indigoAccent),
            const SizedBox(height: 16),
            const Text(
              'Offline Bus Navigation & Alarm',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '100% Free - Works without Internet using Satellite GPS & Offline P2P Mesh',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.indigoAccent,
              ),
              icon: const Icon(Icons.app_registration),
              label: const Text('SETUP REGISTRATION', style: TextStyle(fontSize: 16)),
              onPressed: () => _showRegistrationDialog(),
            )
          ],
        ),
      ),
    );
  }

  void _showRegistrationDialog() {
    final nameCtrl = TextEditingController(text: _studentName);
    BusRoute? selectedR = _selectedRoute ?? (_routes.isNotEmpty ? _routes.first : null);
    BusStop? selectedS = _selectedStop ?? (selectedR?.stops.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Student Offline Registration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BusRoute>(
                value: selectedR,
                decoration: const InputDecoration(
                  labelText: 'Select Route Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.route),
                ),
                items: _routes.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(r.routeId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (val) {
                  setModalState(() {
                    selectedR = val;
                    selectedS = val?.stops.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (selectedR != null)
                DropdownButtonFormField<BusStop>(
                  value: selectedS,
                  decoration: const InputDecoration(
                    labelText: 'Select Target Bus Stop',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: selectedR!.stops.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text('${s.name} (${s.time})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedS = val);
                  },
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  onPressed: () {
                    setState(() {
                      _studentName = nameCtrl.text;
                      _selectedRoute = selectedR;
                      _selectedStop = selectedS;
                      _isRegistered = true;
                    });
                    Navigator.of(ctx).pop();
                    _startTracking();
                  },
                  child: const Text('SAVE & START ALARM SYSTEM', style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      color: Colors.indigo.shade900.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.indigoAccent,
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'Assigned: ${_selectedRoute?.routeId} • Stop: ${_selectedStop?.name}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Driver: ${_selectedRoute?.driver} (${_selectedRoute?.contact})',
                    style: const TextStyle(fontSize: 12, color: Colors.indigoAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceTrackerCard() {
    bool isNear = _distanceToStopMeters <= _alarmRadiusMeters;

    return Card(
      color: isNear ? Colors.red.shade900.withOpacity(0.4) : Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar, color: Colors.indigoAccent),
                    SizedBox(width: 8),
                    Text('Target Stop Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('GPS ACTIVE (OFFLINE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _distanceToStopMeters > 90000
                  ? 'Calculating GPS...'
                  : '${(_distanceToStopMeters / 1000).toStringAsFixed(2)} km',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: isNear ? Colors.redAccent : Colors.white,
              ),
            ),
            Text(
              'Target Stop: ${_selectedStop?.name} (${_selectedStop?.time})',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active, size: 18, color: Colors.amber),
                const SizedBox(width: 6),
                Text('Alarm set to trigger at ${_alarmRadiusMeters.round()} meters'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdBusRadarCard() {
    // Crowd Sourced Bus Detection Logic:
    int peersInBusCount = _nearbyPeers.where((p) => p.isInBus).length;
    bool isBusLocationDetected = peersInBusCount >= 2;

    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cell_tower, color: Colors.indigoAccent),
                const SizedBox(width: 8),
                Text('Offline P2P Mesh (${_selectedRoute?.routeId} Peers)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBusLocationDetected
                    ? Colors.green.shade900.withOpacity(0.4)
                    : Colors.amber.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isBusLocationDetected ? Colors.green : Colors.amber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isBusLocationDetected ? Icons.verified : Icons.error_outline,
                    color: isBusLocationDetected ? Colors.greenAccent : Colors.amberAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBusLocationDetected
                              ? 'BUS DETECTED EN ROUTE!'
                              : 'Scanning for Bus Cluster...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isBusLocationDetected
                              ? '$peersInBusCount students on your route moving at >15 km/h together'
                              : 'Single students detected at stops',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Nearby Route Peers (No Internet Required):',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._nearbyPeers.map((peer) {
              return ListTile(
                dense: true,
                leading: Icon(
                  peer.isInBus ? Icons.directions_bus : Icons.person_pin_circle,
                  color: peer.isInBus ? Colors.greenAccent : Colors.amberAccent,
                ),
                title: Text('${peer.name} (${peer.stopName})'),
                subtitle: Text('Speed: ${peer.speedKmH} km/h • Mode: ${peer.isInBus ? "IN BUS" : "WAITING"}'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStopsCard() {
    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_selectedRoute?.name} - Timetable',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedRoute?.stops.length ?? 0,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.white12),
              itemBuilder: (ctx, i) {
                final stop = _selectedRoute!.stops[i];
                bool isTarget = stop.name == _selectedStop?.name;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isTarget ? Icons.notifications_active : Icons.location_on,
                    color: isTarget ? Colors.redAccent : Colors.grey,
                  ),
                  title: Text(
                    stop.name,
                    style: TextStyle(
                      fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                      color: isTarget ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  trailing: Text(stop.time, style: const TextStyle(color: Colors.grey)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
