import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ble_service.dart';
import 'calculate_distance.dart';
import 'firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class LocationService {
  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      intervalDuration: Duration(seconds: 1),
    ),
  );

  Future<Position> getCurrent() async {
    return Geolocator.getCurrentPosition();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ble = BleService();
  final firestore = FirestoreService();
  String status = "Disconnected";
  String deviceId = "-";
  bool tracking = false;
  bool isConnected = false;
  String pairedDeviceId = "";
  StreamSubscription<Position>? writePositionSub;
  StreamSubscription? readPositionSub;
  StreamSubscription<Position>? locationSub;
  static const platform = MethodChannel('foreground_service');
  DateTime lastFirebaseSent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastBleSent = DateTime.fromMillisecondsSinceEpoch(0);
  final TextEditingController pairedDeviceController = TextEditingController();

  Timer? distanceTimer;

  double myLat = 0.0;
  double myLng = 0.0;
  double? otherLat;
  double? otherLng;
  double distance = 0.0;

// ================= Location Services =================
  void startLocationUpload() {
    if (locationSub != null) return; // prevent duplicates

    locationSub = LocationService().positionStream.listen((pos) {
      if (DateTime.now().difference(lastFirebaseSent).inMinutes <= 1) return;      // Updates to Firestore to once per minute
      lastFirebaseSent = DateTime.now();
      onLocationUpdate(pos);

      debugPrint(
        "Location update: "
        "Lat=${pos.latitude}, Lng=${pos.longitude}"
      );
    });
  }

  void stopLocationUpload() {
    locationSub?.cancel();
    locationSub = null;
  }

  void onLocationUpdate(Position pos) {
    firestore.updateLocation(
      deviceId: deviceId,
      lat: pos.latitude,
      lng: pos.longitude,
      state: status,
      pairedWith: pairedDeviceId,
    );
  }

// ================= Phone Tracking Services =================
  void startPhoneTracking() async {
    if (pairedDeviceId.isEmpty) return;

    debugPrint("Starting phone tracking for $pairedDeviceId");

    if (writePositionSub != null) {writePositionSub?.cancel(); writePositionSub = null;}
    if (readPositionSub != null) {readPositionSub?.cancel(); readPositionSub = null;}

    debugPrint("Starting Firebase listening.");
    readPositionSub = firestore.listenToDevice(pairedDeviceId).listen((doc) {
      if (!doc.exists) return;

      final lat = doc['latitude'];
      final lng = doc['longitude'];

      if (lat == null || lng == null) {
        debugPrint("Firebase location fields missing");
        return;
      }

      debugPrint("Received other device location: $lat, $lng");

      setState(() {
        otherLat = doc['latitude'];
        otherLng = doc['longitude'];
      });
    });

    debugPrint("Starting GPS listener...");
    writePositionSub = LocationService().positionStream.listen((pos) async {
      myLat = pos.latitude;
      myLng = pos.longitude;
    },
      onError: (err) {
        debugPrint("Error in phone tracking location stream: $err");
      }, cancelOnError: false,
    );
    startDistanceLoop();
  }

  void stopPhoneTracking() {
    writePositionSub?.cancel();
    writePositionSub = null;

    readPositionSub?.cancel();
    readPositionSub = null;

    distanceTimer?.cancel();
    distanceTimer = null;

    debugPrint("Stopped phone tracking");
  }

  void startDistanceLoop() {
    distanceTimer?.cancel();
    debugPrint("Starting distance loop");
    distanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      //if (myLat == null || myLng == null) return;
      if (otherLat == null || otherLng == null) return;
      
      final raw = calculateDistance(
        myLat,
        myLng,
        otherLat!,
        otherLng!,
      );

      // Implement average smoothing
      final dist = smoothDistance(raw);

      setState(() => distance = dist);

      final zone = calculateZone(dist);
      ble.send("DIST:$zone");
   });
  }

// ================= UI and Other Services =================
  void resetToDefault() {
    stopPhoneTracking();
    stopLocationUpload();
    pairedDeviceController.clear();

    setState(() {
      tracking = false;
      pairedDeviceId = "";
      otherLat = null;
      otherLng = null;
      distance = 0.0;
      isConnected = false;
      status = "Disconnected";
      deviceId = "-";
    });
  }

  Future<void> openInGoogleMaps() async {
    if (otherLat == 0.0 && otherLng == 0.0) return;
    final uri = Uri.parse("geo:$otherLat,$otherLng?q=$otherLat,$otherLng");

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    ble.onMessage = handleBleMessage;
  }

  void handleBleMessage(String msg) {
    debugPrint("handleBleMessage: $msg");

    if (msg.startsWith("STATE:")) {
      final newState = msg.replaceAll("STATE:", "").trim();
      status = newState;

      if (newState == "TRACKING") {
        startPhoneTracking();
      }

      if (newState == "CONNECTED") {
        startLocationUpload();
        stopPhoneTracking();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wearable Locator")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Status: $status"),
            Text("Connected Device: $deviceId"),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () async {
                await ble.startScan(() {
                  if (mounted) setState(() {});
                });
              },
              child: const Text("Scan for Devices"),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: ble.scanResults.length,
                itemBuilder: (_, i) {
                  final r = ble.scanResults[i];

                  final name = r.advertisementData.advName.isNotEmpty
                      ? r.advertisementData.advName
                      : r.device.name;

                  return ListTile(
                    title: Text(name),
                    subtitle: Text(r.device.id.id),
                    trailing: isConnected ? const Icon(Icons.lock) : const Icon(Icons.bluetooth),
                    onTap: isConnected ? null : () async {
                      await ble.connect(r.device);

                      setState(() {
                        status = "Connected";
                        deviceId = name;
                        isConnected = true;
                      });

                      ble.connectionState.listen((state) {
                        if (state == BluetoothConnectionState.disconnected) {
                          if (!mounted) return;
                          setState(() {
                            resetToDefault();
                          });
                        }
                      });
                    },
                  );
                },
              ),
            ),

            TextField(
              controller: pairedDeviceController,
              enabled: ble.device != null,
              decoration: const InputDecoration(labelText: "Paired Device ID"),
              onChanged: (val) {
                pairedDeviceId = val;
              },
            ),

            Text(
              "Paired Device Location (Last Known):\n"
              "Lat: ${otherLat?.toStringAsFixed(6)}\n"
              "Lng: ${otherLng?.toStringAsFixed(6)}\n"
              "Approximate Distance: ${distance.toStringAsFixed(2)} meters\n",
            ),

            ElevatedButton(
              onPressed: (otherLat != 0.0 && otherLng != 0.0)
                  ? openInGoogleMaps
                  : null,
              child: const Text("Open Last Known Location in Maps"),
            ),
          ],
        ),
      ),
    );
  }
}
