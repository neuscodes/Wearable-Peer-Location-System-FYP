import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String SERVICE_UUID = "6E416761-1A98-4F47-9B7A-8F6B2CCF0001";
const String TX_UUID = "6E416762-1A98-4F47-9B7A-8F6B2CCF0002"; // phone → ESP32
const String RX_UUID = "6E416763-1A98-4F47-9B7A-8F6B2CCF0003"; // ESP32 → phone

Future<void> requestBlePermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    Permission.locationAlways,
  ].request();
}

class BleService extends ChangeNotifier{
  BluetoothDevice? device;
  BluetoothCharacteristic? txChar;
  BluetoothCharacteristic? rxChar;
  StreamSubscription<List<ScanResult>>? _scanSub;

  final List<ScanResult> scanResults = [];
  Function(String)? onMessage;

  Future<void> startScan(VoidCallback onUpdate) async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    scanResults.clear();
    onUpdate();
    await requestBlePermissions();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;

      for (var r in results) {
        final name = r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.name;

        debugPrint("BLE: $name");

        if (name.startsWith("DEV")) {
          if (!scanResults.any((e) => e.device.id == r.device.id)) {
            scanResults.add(r);
            changed = true;
          }
        }
      }
      if (changed) {
        onUpdate();
      }
    });
  }

  Future<void> connect(BluetoothDevice d) async {
    device = d;
    await d.connect(autoConnect: false);
    await discoverGatt(d);
    await send("STATE?");
  }

  Future<void> discoverGatt(BluetoothDevice d) async {
    final services = await d.discoverServices();
    for (var s in services) {
      debugPrint("SERVICE: ${s.uuid.str}");

      // for (var c in s.characteristics) {     For debugging only
      //   debugPrint(
      //     "  CHAR: ${c.uuid.str} "
      //     "notify=${c.properties.notify} "
      //     "write=${c.properties.write}"
      //   );
      // }
      
      if (s.uuid.toString().toUpperCase() == SERVICE_UUID) {
        for (var c in s.characteristics) {
          String uuid = c.uuid.str.toUpperCase();

          if (uuid == TX_UUID.toUpperCase()) {
            // ESP32 > Phone (notify)
            txChar = c;
            await c.setNotifyValue(true);
            c.value.listen((value) {
              if (value.isEmpty) return;
              final msg = utf8.decode(value);
              debugPrint("ESP32 > APP: $msg");
              onMessage?.call(msg.trim());
            });
          }
          if (uuid == RX_UUID.toUpperCase()) {
            // Phone > ESP32 (write)
            rxChar = c;
          }
        }
      }
    }
  }

  // Phone TX > ESP32 RX
  Future<void> send(String msg) async {
    if (rxChar == null) return;
    await rxChar!.write(utf8.encode(msg), withoutResponse: true);
  }

  Stream<BluetoothConnectionState> get connectionState =>
    device!.connectionState;

  Future<void> disconnect() async {
    await device?.disconnect();
    device = null;
  }
}
