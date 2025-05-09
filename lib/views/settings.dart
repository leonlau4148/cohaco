import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cohaco/views/remote.dart'; // Replace with the actual path to your RemotePage file
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:cohaco/dmanager.dart'; // Import DeviceManager

class SettingsPage extends StatefulWidget {
  final String deviceId;
  final String devicePass;
  final String uid;

  const SettingsPage({
    super.key,
    required this.deviceId,
    required this.devicePass,
    required this.uid,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedOption = 'Wifi Only';
  final List<String> _options = ['Access Point', 'Wifi Only'];
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isTriggerScanLoading = false; // New state variable
  final _database = FirebaseDatabase.instance;

  List<String> _wifiNetworks = [];
  List<String> wifiList = [];
  String? _selectedSSID;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchWifiNetworks() async {
    final fullMachineName = widget.deviceId;
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref();
    final snapshot = await databaseReference.child("devices/$fullMachineName/wifiScan").get();

    if (snapshot.exists) {
      final data = snapshot.value as List<dynamic>; // Treat it as a List
      setState(() {
        // Map the List to extract the 'ssid' field
        _wifiNetworks = data
            .where((network) => network != null) // Ensure non-null entries
            .map((network) => (network as Map<dynamic, dynamic>)['ssid'] as String)
            .toList();
      });
    } else {
      setState(() {
        _wifiNetworks = [];
      });
    }
  }

  Future<void> _fetchWifiNetworksEsp() async {
    final fullMachineName = widget.deviceId;
    final devicePassword = widget.devicePass;
    print(fullMachineName);
    print(devicePassword);
    final url = Uri.http(fullMachineName + ".local", "/scan-networks");
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Basic ' + base64Encode(utf8.encode('$fullMachineName:$devicePassword')),
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      setState(() {
        _wifiNetworks = data.map((network) => network['ssid'] as String).toList();
      });
    } else {
      setState(() {
        _wifiNetworks = [];
      });
      print('Failed to fetch Wi-Fi networks: ${response.body}');
    }
  }

  Future<void> tiggerNetworks() async {
    setState(() {
      _isTriggerScanLoading = true; // Show loading indicator for Trigger Wi-Fi Scan button
    });

    try {
      // Load devices from DeviceManager if offline
      await DeviceManager.instance.refreshDevices(widget.uid);
      final devices = DeviceManager.instance.devices;

      // Find the device with the matching deviceId
      final device = devices.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => {});

      if (device.isNotEmpty) {
        String addDeviceConnection = device['addDeviceConnection'];
        print('Device ID: ${device['deviceId']}, Connection: $addDeviceConnection');

        // Handle offline scenario
        final connectivityResult = await (Connectivity().checkConnectivity());
        if (connectivityResult == ConnectivityResult.none) {
          _showErrorDialog('Please connect to a network first');
        } else {
          if (addDeviceConnection == 'offline') {
            await _fetchWifiNetworksEsp();
          } else {
            await _triggerWifiScan();
            await Future.delayed(const Duration(seconds: 5));
            await _fetchWifiNetworks();
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to scan Wi-Fi networks: $e');
    } finally {
      setState(() {
        _isTriggerScanLoading = false; // Hide loading indicator for Trigger Wi-Fi Scan button
      });
    }
  }

  Future<Map<String, String>> _getDeviceCredentials() async {
    // Try DeviceManager first
    await DeviceManager.instance.refreshDevices(widget.uid);
    final devices = DeviceManager.instance.devices;

    // Find the device with the matching deviceId
    final device = devices.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => {});

    if (device.isNotEmpty) {
      return {
        'deviceId': device['deviceId'],
        'devicePass': device['devicePass'],
      };
    }

    // Otherwise try Firebase using current user's UID
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _database.ref('users/${user.uid}/devices').get();

        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          // Assuming first device for now
          final firstDevice = data.values.first as Map<dynamic, dynamic>;
          final fbDeviceId = firstDevice['deviceId'] as String;
          final fbDevicePass = firstDevice['devicePass'] as String;

          // Cache in DeviceManager
          await DeviceManager.instance.updateDevice(widget.uid, [
            {
              'deviceId': fbDeviceId,
              'devicePass': fbDevicePass,
            }
          ]);

          return {
            'deviceId': fbDeviceId,
            'devicePass': fbDevicePass,
          };
        }
      }
    } catch (e) {
      print('Firebase error: $e');
    }

    return {
      'deviceId': '',
      'devicePass': '',
    };
  }

  Future<void> connectToWiFi(
    String ssid,
    String password,
  ) async {
    print(ssid);
    final url = Uri.http("${widget.deviceId}.local", "/switch-mode");
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'mode': 'online',
          'ssid': ssid,
          'password': password,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to connect: ${response.body}');
      }
      // await _database.ref().child("devices/${widget.deviceId}/triggerAP").set(false);
      // Go back to devices
    } catch (e) {
      // Navigate to devices
      Navigator.pop(context);
      // Reload devices
    }
  }

  Future<void> saveCredentialsToFirebase(String ssid, String password) async {
    final fullMachineName = widget.deviceId;
    String path = "devices/$fullMachineName/credentials/";
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref();

    await databaseReference.child(path + "ssid").set(ssid);
    await databaseReference.child(path + "password").set(password);
    _triggerSaveWifi();
    await _database.ref().child("devices/$fullMachineName/triggerAP").set(false);
  }

  Future<void> handleConnection(
    String ssid,
    String password,
  ) async {
    await DeviceManager.instance.refreshDevices(widget.uid);
    final devices = DeviceManager.instance.devices;

    // Find the device with the matching deviceId
    final device = devices.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => {});

    if (device.isNotEmpty) {
      String addDeviceConnection = device['addDeviceConnection'];
      print('Device ID: ${device['deviceId']}, Connection: $addDeviceConnection');

      // Handle offline scenario
      if (addDeviceConnection == 'offline') {
        print("passing offline ");
        // Change addDeviceConnection to online in DeviceManager
        device['wifiStatus'] = 'true';
        device['addDeviceConnection'] = 'online';
        // Save to DeviceManager
        await DeviceManager.instance.updateDevice(widget.uid, devices);
        await connectToWiFi(ssid, password);
      } else {
        await saveCredentialsToFirebase(ssid, password);
        device['wifiStatus'] = 'true';
        device['addDeviceConnection'] = 'online';
        await DeviceManager.instance.updateDevice(widget.uid, devices);

        Navigator.pop(context);
      }
    }
  }

  void _showConnectionTimerDialog(String mode, [String? ssid]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        int secondsRemaining = 300; // 5 minutes

        return StatefulBuilder(
          builder: (context, setState) {
            Future.delayed(Duration(seconds: 1), () {
              if (secondsRemaining > 0 && Navigator.canPop(context)) {
                setState(() {
                  secondsRemaining--;
                });
              } else if (secondsRemaining == 0 && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });

            return AlertDialog(
              title: Text(mode == 'WiFi' ? 'WiFi Connection Status' : 'Access Point Mode'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode == 'WiFi' ? Icons.wifi : Icons.wifi_tethering,
                    size: 50,
                    color: Colors.brown,
                  ),
                  SizedBox(height: 10),
                  if (mode == 'WiFi') ...[
                    Text('Connected to: $ssid'),
                    SizedBox(height: 20),
                  ] else ...[
                    Text('Device is in AP Mode'),
                    SizedBox(height: 20),
                  ],
                  Text(mode == 'WiFi' ? 'Connection will timeout in:' : 'AP Mode will disable in:'),
                  SizedBox(height: 10),
                  Text(
                    '${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(secondsRemaining % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    if (_selectedOption == 'Wifi Only' &&
        (_selectedSSID == null || _selectedSSID!.isEmpty || _passwordController.text.isEmpty)) {
      _showErrorDialog('Please select a Wi-Fi network and enter the password.');
      return;
    }

    bool hasInternet = await _hasInternetAccess();
    setState(() => _isLoading = true);
    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      if (_selectedOption == 'Wifi Only') {
        await handleConnection(_selectedSSID!, _passwordController.text);
        _showConnectionTimerDialog('WiFi', _selectedSSID);
        //snackbar connected
        SnackBar(
          content: Text('Connected to $_selectedSSID'),
          backgroundColor: Colors.brown,
          duration: Duration(seconds: 2),
        );
      } else if (_selectedOption == 'Access Point') {
        await handletriggerAP();
        //show timer dialog countdown 5 mins
        _showConnectionTimerDialog('AP');
      }
    } catch (e) {
      //snackbar error
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Settings saved successfully'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(error),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _triggerWifiScan() async {
    final fullMachineName = widget.deviceId;
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref();
    await databaseReference.child("devices/$fullMachineName/triggerScan").set(true);
  }

  Future<void> _triggerAccessPointSetup() async {
    final fullMachineName = widget.deviceId;
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref();
    await databaseReference.child("devices/$fullMachineName/triggerAP").set(true);
  }

  Future<void> _triggerSaveWifi() async {
    final fullMachineName = widget.deviceId;
    DatabaseReference databaseReference = FirebaseDatabase.instance.ref();
    await databaseReference.child("devices/$fullMachineName/triggerSave").set(true);
  }

  Future<void> switchToAPMode() async {
    final fullMachineName = widget.deviceId;
    final devicePassword = widget.devicePass;
    final url = Uri.http(fullMachineName + ".local", "/switch-mode"); // Replace with your actual ESP32 endpoint
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Basic ' + base64Encode(utf8.encode('$fullMachineName:$devicePassword')),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'mode': 'ap'}, // Request to switch to AP mode
    );

    if (response.statusCode == 200) {
      print('Switched to AP mode successfully');
    } else {
      print('Failed to switch to AP mode: ${response.body}');
    }
  }

  Future<void> handletriggerAP() async {
    // Load devices from DeviceManager if offline
    await DeviceManager.instance.refreshDevices(widget.uid);
    final devices = DeviceManager.instance.devices;

    // Find the device with the matching deviceId
    final device = devices.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => {});

    if (device.isNotEmpty) {
      String addDeviceConnection = device['addDeviceConnection'];
      print('Device ID: ${device['deviceId']}, Connection: $addDeviceConnection');

      // Handle offline scenario
      if (addDeviceConnection == 'offline') {
        device['addDeviceConnection'] = 'offline';
        device['wifiStatus'] = 'false';
        await DeviceManager.instance.updateDevice(widget.uid, devices);
        await switchToAPMode();

        Navigator.pop(context);
      } else if (addDeviceConnection == 'online') {
        // Change addDeviceConnection to offline in DeviceManager
        device['addDeviceConnection'] = 'offline';
        device['wifiStatus'] = 'false';
        // Save to DeviceManager
        await DeviceManager.instance.updateDevice(widget.uid, devices);
        await _triggerAccessPointSetup();

        Navigator.pop(context);
        //go back to devices

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device is in AP mode'),
            backgroundColor: Colors.brown,
            duration: Duration(seconds: 2),
          ),
        );
        //delay
        await Future.delayed(const Duration(seconds: 5));
        DatabaseReference dbRef = FirebaseDatabase.instance.ref();
        await dbRef.child('/devices/${device['deviceId']}').remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Connection Type:'),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedOption,
                    isExpanded: true,
                    isDense: true,
                    alignment: AlignmentDirectional.centerStart,
                    icon: const Icon(Icons.arrow_drop_down),
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    items: _options.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedOption = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_selectedOption == 'Wifi Only') ...[
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: _selectedSSID,
                isExpanded: true,
                hint: const Text('Select Wifi Network'),
                items: _wifiNetworks.map((String ssid) {
                  return DropdownMenuItem<String>(
                    value: ssid,
                    child: Text(ssid),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSSID = newValue;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
            if (_selectedOption == 'Wifi Only') ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isTriggerScanLoading ? null : tiggerNetworks,
                child: _isTriggerScanLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Wi-Fi Scan'),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
