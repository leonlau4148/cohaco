import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceManager {
  static final DeviceManager _instance = DeviceManager._internal();
  factory DeviceManager() => _instance;
  DeviceManager._internal();

  final FlutterSecureStorage _storage = FlutterSecureStorage();
  List<Map<String, dynamic>> _devices = [];

  // Access the singleton instance
  static DeviceManager get instance => _instance;

  // Get current devices
  List<Map<String, dynamic>> get devices => _devices;

  // Initialize devices (load from storage)
  Future<void> initialize(String uid) async {
    final devicesJson = await _storage.read(key: 'users_${uid}_devices');
    _devices = devicesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(devicesJson)) : [];
  }

  // Update devices in memory and local storage
  Future<void> updateDevice(String uid, List<Map<String, dynamic>> updatedDevices) async {
    _devices = updatedDevices;
    await _storage.write(key: 'users_${uid}_devices', value: jsonEncode(updatedDevices));
  }

  // Refresh devices from storage
  Future<void> refreshDevices(String uid) async {
    await initialize(uid);
  }
}
