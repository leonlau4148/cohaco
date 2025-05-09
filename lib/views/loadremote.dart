import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '/global.dart';
import 'package:flutter/material.dart';
import '/views/remote.dart'; // Make sure to import the Remote screen

class LoadRemote extends StatelessWidget {
  final String deviceId;
  final String initialName;
  final String devicePass;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  String uid = ''; // Define the uid variable

  LoadRemote({required this.deviceId, required this.initialName, required this.devicePass});

  Future<void> _initializeRemote() async {
    // Simulate a delay for fetching data or any initialization
    uid = await _storage.read(key: 'uid') ?? '';
    await Future.delayed(Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeRemote(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while waiting for the future to complete
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            // Handle error state
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            // Show the Remote screen once the future completes
            return Remote(
              deviceId: deviceId,
              initialName: initialName,
              devicePass: devicePass,
              uid: uid,
            );
          }
        },
      ),
    );
  }
}
