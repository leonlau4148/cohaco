import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'devices.dart';
import 'login.dart';
import 'dart:convert';

class LoadScreen extends StatefulWidget {
  @override
  _LoadScreenState createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  final _storage = FlutterSecureStorage();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  // Helper function to check actual internet access
  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (e) {
      // No internet access
    }
    return false;
  }

  Future<void> _syncOfflineDevices() async {
    bool hasInternet = await _hasInternetAccess();
    if (!hasInternet) return;

    // Get current user
    final user = await _storage.read(key: 'uid');
    if (user == null) return;

    // Read existing devices from local storage
    String? devicesJson = await _storage.read(key: 'users_${user}_devices');
    List<Map<String, dynamic>> localDevices =
        devicesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(devicesJson)) : [];

    final dbRef = FirebaseDatabase.instance.ref();
    String connectionStatus = '';
    String devicewifiStatus = '';
    // Sync each offline device
    for (final deviceData in localDevices) {
      print((deviceData['addDeviceConnection'].toString()));
      print(deviceData['wifiStatus'].toString());
      if (deviceData['wifiStatus'] == 'true') {
        final deviceId = deviceData['deviceId'];
        // Update local storage to mark the device as synced
        deviceData['addDeviceConnection'] = 'online';
        connectionStatus = 'online';
        devicewifiStatus = 'true';
        // Update Firebase
        await dbRef.child('users/$user/devices/$deviceId').set({
          'deviceId': deviceId,
          'devicePass': deviceData['devicePass'],
          'name': deviceData['name'],
          'addDeviceConnection': connectionStatus,
          'wifiStatus': devicewifiStatus,
          'createdAt': ServerValue.timestamp,
        });
      } else if (deviceData['wifiStatus'] == 'false') {
        final deviceId = deviceData['deviceId'];

        // Update local storage to mark the device as synced
        deviceData['addDeviceConnection'] = 'offline';
        connectionStatus = 'offline';
        devicewifiStatus = 'false';
        await dbRef.child('users/$user/devices/$deviceId').set({
          'deviceId': deviceId,
          'devicePass': deviceData['devicePass'],
          'name': deviceData['name'],
          'addDeviceConnection': connectionStatus,
          'wifiStatus': devicewifiStatus,
          'createdAt': ServerValue.timestamp,
        });
      }
    }

    // Store the updated list back to local storage
    await _storage.write(
      key: 'users_${user}_devices',
      value: jsonEncode(localDevices),
    );
  }

  Future<void> _attemptAutoLogin() async {
    try {
      String? rememberMe = await _storage.read(key: 'remember_me');
      String? user = await _storage.read(key: 'uid');
      bool hasInternet = await _hasInternetAccess();

      if (user != null) {
        // User exists in storage
        if (rememberMe == 'true') {
          // Remember me is true - allow offline access
          await _syncOfflineDevices(); // Will only sync if internet available

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Devices()),
            );
          }
          return;
        } else {
          // Remember me is false - require internet
          if (!hasInternet) {
            // No internet - force logout
            await _clearStorageAndLogout();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthPage()),
              );
            }
            return;
          }

          // Has internet - proceed normally
          await _syncOfflineDevices();
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Devices()),
            );
          }
          return;
        }
      }

      // No user found - go to login
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthPage()),
        );
      }
    } catch (e) {
      // Handle errors by redirecting to login
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthPage()),
        );
      }
    }
  }

  Future<void> _clearStorageAndLogout() async {
    await _auth.signOut();
    await _storage.delete(key: 'session_token');
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'password');
    await _storage.delete(key: 'remember_me');
    await _storage.delete(key: 'user_token');
    await _storage.delete(key: 'uid');
    await _storage.delete(key: 'devices');
    await _storage.delete(key: 'userdetails');
    if (context.mounted) {
      //remove the current page from the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
