import 'dart:io';

import 'package:cohaco/dmanager.dart';

import '/global.dart';
import '/views/addDevice.dart';
import '/views/home.dart';
import '/views/loadremote.dart'; // Import LoadRemote
import '/views/remote.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'profile.dart'; // Make sure to import ProfilePage
import 'dart:convert';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  State<Devices> createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  List<Map<String, dynamic>> devices = [];
  final _storage = FlutterSecureStorage();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    // Perform any necessary cleanup here
    super.dispose();
  }

  // Helper function to check actual internet access
  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // No internet access
      return false;
    }
  }

  Future<void> _loadDevices() async {
    try {
      // Retrieve user details from storage if offline
      final user = await _storage.read(key: 'uid');

      if (user == null) return;

      bool hasInternet = await _hasInternetAccess();
      if (hasInternet) {
        print("internet access devices");
        // Load devices from Firebase using UID
        final dbRef = FirebaseDatabase.instance.ref();
        final snapshot = await dbRef.child('users/$user/devices').get();

        if (snapshot.exists) {
          final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> fetchedDevices = values.entries.map((entry) {
            final Map<String, dynamic> device = Map<String, dynamic>.from(entry.value as Map);
            device['deviceId'] = entry.key;
            return device;
          }).toList();

          // Store devices in local storage
          await DeviceManager.instance.updateDevice(user, fetchedDevices);

          if (mounted) {
            setState(() {
              devices = fetchedDevices;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              devices = [];
            });
          }
        }
      } else {
        print('No internet access devices');
        // Load devices from local storage if offline
        await DeviceManager.instance.refreshDevices(user);
        devices = DeviceManager.instance.devices;

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.devices),
                title: Text('Add Device'),
                onTap: () async {
                  final usercred = await _storage.read(key: 'uid');
                  if (usercred != null) {
                    Navigator.of(context).pop(); // Close dialog
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddDevicePage(usercredentials: usercred)),
                    );
                    if (result == true) {
                      _loadDevices(); // Reload devices if a device was added
                    }
                  } else {
                    // Handle the case where usercred is null
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to get user credentials')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int index) async {
    final device = devices[index];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Device'),
          content: Text('Are you sure you want to delete ${device['name'] ?? device['deviceId']}?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                try {
                  final dbRef = FirebaseDatabase.instance.ref();
                  final deviceId = device['deviceId'];
                  // Check if device exists locally
                  List<Map<String, dynamic>> localDevices = DeviceManager.instance.devices;
                  bool deviceExistsLocally = localDevices.any((device) => device['deviceId'] == deviceId);

                  // Check if there's actual internet access
                  bool hasInternet = await _hasInternetAccess();

                  if (hasInternet) {
                    // Check if device exists in Firebase
                    final snapshot = await dbRef.child('users/${user.uid}/devices/$deviceId').get();
                    bool deviceExistsInFirebase = snapshot.exists;

                    if (deviceExistsInFirebase) {
                      // Delete from Firebase if it exists there
                      await dbRef.child('users/${user.uid}/devices/$deviceId').remove();
                      //Navigator.of(context).pop();
                      //_loadDevices(); // Reload devices
                    }
                  }

                  // Always delete from local storage if it exists locally
                  if (deviceExistsLocally) {
                    localDevices.removeWhere((device) => device['deviceId'] == deviceId);
                    await DeviceManager.instance.updateDevice(user.uid, localDevices);
                    //Navigator.of(context).pop();
                    // Reload devices
                  }
                  Navigator.of(context).pop();
                  _loadDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Device deleted successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete device: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmEdit(BuildContext context, int index) {
    final device = devices[index];
    final nameController = TextEditingController(text: device['name'] ?? device['deviceId']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Device'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'Device Name'),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final updatedDevice = {
                  ...device,
                  'name': nameController.text,
                };

                // Check if there's actual internet access
                bool hasInternet = await _hasInternetAccess();

                if (hasInternet) {
                  // Update in Firebase
                  final dbRef = FirebaseDatabase.instance.ref();
                  await dbRef
                      .child('users/${user.uid}/devices/${device['deviceId']}')
                      .update({'name': nameController.text});
                }

                // Read existing devices from local storage
                List<Map<String, dynamic>> localDevices = DeviceManager.instance.devices;

                // Update the device in the list
                int deviceIndex = localDevices.indexWhere((d) => d['deviceId'] == device['deviceId']);
                if (deviceIndex != -1) {
                  localDevices[deviceIndex]['name'] = nameController.text;
                }

                // Store the updated list back to local storage
                await DeviceManager.instance.updateDevice(user.uid, localDevices);

                Navigator.of(context).pop();
                _loadDevices(); // Reload devices
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToProfile(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }

  Future<void> _navigateToRemote(BuildContext context, Map<String, dynamic> device) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No network connection'),
        ),
      );
    } else {
      // Refresh device data from DeviceManager
      final user = await _storage.read(key: 'uid');
      await DeviceManager.instance.refreshDevices(user.toString());
      final devices = DeviceManager.instance.devices;
      final deviceId = device['deviceId'];
      final deviceData = devices.firstWhere((d) => d['deviceId'] == deviceId, orElse: () => {});

      if (deviceData.isNotEmpty) {
        // Refresh addDeviceConnection
        device['addDeviceConnection'] = deviceData['addDeviceConnection'];
        print(device['addDeviceConnection'] + " showing device connection");

        bool hasInternet = await _hasInternetAccess();
        if (device['addDeviceConnection'] == 'offline' && hasInternet) {
          print(device['addDeviceConnection']);
          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device is on offline mode. Please connect to the device wifi and try again.'),
            ),
          );
        } else if (device['addDeviceConnection'] == 'online' && !hasInternet) {
          print(device['addDeviceConnection']);
          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device is on online mode. No internet connection please try again.'),
            ),
          );
        } else {
          final user = await _storage.read(key: 'uid');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Remote(
                deviceId: deviceData['deviceId'],
                initialName: deviceData['name'] ?? deviceData['deviceId'],
                devicePass: deviceData['devicePass'],
                uid: user.toString(),
              ),
            ),
          );
        }
      } else {
        // Show snackbar if the device is not found in storage
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device information is incomplete. Please check the device details and try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Icon(Icons.person, color: Colors.black, size: 40.0),
                ),
              ),
              onPressed: () {
                _navigateToProfile(context); // Navigate to profile page
              },
            ),
            Text(
              'Devices',
              style: TextStyle(color: Colors.black),
            ),
            IconButton(
              icon: Icon(Icons.add, color: Colors.black),
              onPressed: () {
                _showAddDeviceDialog(context);
              },
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? Center(child: Text('No devices found'))
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> device = devices[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Slidable(
                        key: ValueKey(device['deviceId']),
                        endActionPane: ActionPane(
                          motion: ScrollMotion(),
                          children: [
                            SizedBox(width: 1),
                            SlidableAction(
                              onPressed: (context) {
                                _confirmEdit(context, index);
                              },
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              icon: Icons.edit,
                              label: 'Edit',
                              borderRadius: BorderRadius.circular(8),
                            ),
                            SizedBox(width: 1),
                            SlidableAction(
                              onPressed: (context) async {
                                _confirmDelete(context, index);
                              },
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Delete',
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _navigateToRemote(context, device);
                          },
                          child: Container(
                            padding: EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  device['name'] ?? device['deviceId'],
                                  style: TextStyle(fontSize: 16.0),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
