import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '/widgets/roundedtextfield.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddDevicePage extends StatefulWidget {
  final Object usercredentials;
  AddDevicePage({required this.usercredentials});
  @override
  _AddDevicePageState createState() => _AddDevicePageState();
}

Future<List<ConnectivityResult>> checkConnectivity() async {
  return await Connectivity().checkConnectivity();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final TextEditingController deviceIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = false;

  @override
  void dispose() {
    deviceIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _addDevice() async {
    bool hasInternet = await _hasInternetAccess();
    final user = await _storage.read(key: 'uid');
    if (user == null) {
      throw Exception('User not logged in');
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final connectivityResult = await checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No network connection');
      }

      final deviceId = deviceIdController.text;
      final password = passwordController.text;

      final isValid = await validateDevice(deviceId, password);

      if (isValid) {
        // var connectivityResult = await Connectivity().checkConnectivity();

        if (hasInternet == true) {
          // Check if the device already exists in Firebase
          final event = await dbRef.child('users/${user}/devices/$deviceId').once();
          if (event.snapshot.exists) {
            throw ('Device already exists');
          }

          // Store device with user token locally
          await _storage.write(
            key: 'users_${user}_devices',
            value: jsonEncode({
              'deviceId': deviceId,
              'devicePass': password,
              'addDeviceConnection': 'online',
              'name': deviceId,
              'uid': user,
              'wifiStatus': 'true',
            }),
          );

          // Store device data in Firebase under user's UID
          await dbRef.child('users/${user}/devices/$deviceId').set({
            'deviceId': deviceId,
            'devicePass': password,
            'name': deviceId,
            'addDeviceConnection': 'online',
            'uid': user,
            'wifiStatus': 'true',
            'createdAt': ServerValue.timestamp,
          });
        } else if (hasInternet == false) {
          print("internet access is false");

          // Read existing devices from local storage
          String? devicesJson = await _storage.read(key: 'users_${user}_devices');
          List<Map<String, dynamic>> localDevices =
              devicesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(devicesJson)) : [];
          // Check if the device already exists in local storage
          if (localDevices.any((device) => device['deviceId'] == deviceId)) {
            throw ('Device already exists');
          }
          // Add the new device to the list
          localDevices.add({
            'deviceId': deviceId,
            'devicePass': password,
            'addDeviceConnection': 'offline',
            'name': deviceId,
            'uid': user,
            'wifiStatus': 'false',
          });

          // Store the updated list back to local storage
          await _storage.write(
            key: 'users_${user}_devices',
            value: jsonEncode(localDevices),
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device added successfully'),
            backgroundColor: Colors.brown,
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
        });
      } else {
        throw ('Invalid device ID or password');
      }
    } catch (e) {
      if (!mounted) return;
      //show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Future<bool> validateDevice(String deviceId, String password) async {
    try {
      // Check if there's actual internet access
      bool hasInternet = await _hasInternetAccess();

      if (hasInternet == true) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return false;

        final token = await user.getIdToken();
        final event = await dbRef.child('devices/$deviceId').once();
        final snapshot = event.snapshot;

        if (snapshot.exists) {
          final deviceData = snapshot.value as Map<dynamic, dynamic>;
          final storedPassword = deviceData['devicePass'] as String;
          return password == storedPassword;
        }
      } else if (hasInternet == false) {
        return await validateDeviceLocally(deviceId, password);
      }
    } catch (e) {
      //snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  // Add new method for local validation
  Future<bool> validateDeviceLocally(String deviceId, String password) async {
    try {
      final url = Uri.http('$deviceId.local');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('$deviceId:$password')),
        },
      );
      return response.statusCode == 200 ? true : false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Device'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RoundedTextField(
                  controller: deviceIdController,
                  label: 'Device ID',
                  icon: Icons.devices,
                  obscureText: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a device ID';
                    }
                    return null;
                  },
                  onSaved: (value) {},
                ),
                const SizedBox(height: 16.0),
                RoundedTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                  onSaved: (value) {},
                  isPasswordField: true,
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  onPressed: _isLoading ? null : _addDevice,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text('Add Device'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
