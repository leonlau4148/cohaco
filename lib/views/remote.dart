import 'package:cohaco/views/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '/global.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '/views/history.dart';
import '/views/home.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class Remote extends StatefulWidget {
  final String deviceId;
  final String initialName; // Add this
  final String devicePass; // Add this
  final String uid;

  const Remote({
    super.key,
    required this.deviceId,
    required this.initialName, // Add this
    required this.devicePass, // Add this
    required this.uid,
  });

  @override
  State<Remote> createState() => _RemoteState();
}

class _RemoteState extends State<Remote> {
  int _currentIndex = 0;
  String deviceName = ''; // Default name
  final _storage = FlutterSecureStorage(); // Add this line to define _storage

  @override
  void initState() {
    super.initState();
    deviceName = widget.initialName; // Set initial name
  }

  // Function to return different widgets for each index
  Widget getBodyContent(int index) {
    switch (index) {
      case 0:
        return HomeView(
          deviceId: widget.deviceId,
          devicePass: widget.devicePass,
          uid: widget.uid,
        ); // Home Screen Content
      case 1:
        // History Screen Content
        return HistoryPage(deviceId: widget.deviceId, devicePass: widget.devicePass, uid: widget.uid);
      case 2:
        return SettingsPage(
          deviceId: widget.deviceId,
          devicePass: widget.devicePass,
          uid: widget.uid,
        ); // Settings Screen Content
      default:
        return Container();
    }
  }

  // Function to return the correct title based on the current index
  String getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return deviceName; // Home Screen
      case 1:
        return 'History'; // History Screen
      case 2:
        return 'Settings'; // Settings Screen
      default:
        return 'App'; // Default title
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine app bar color and icon/text color based on the current index
    final bool isHistorySelected = _currentIndex == 1;
    final bool isSettingsSelected = _currentIndex == 2;
    final Color appBarColor = isHistorySelected || isSettingsSelected ? Colors.white : Colors.brown;
    final Color appBarTextColor = isHistorySelected || isSettingsSelected ? Colors.black : Colors.white;
    //settings color

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: appBarTextColor),
              onPressed: () {
                //go back to devices
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  getAppBarTitle(_currentIndex), // Dynamic AppBar title
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: appBarTextColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 48), // Padding for symmetry
          ],
        ),
      ),
      body: getBodyContent(_currentIndex), // Dynamic content based on current index

      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.white,
        color: Colors.brown,
        buttonBackgroundColor: Colors.brown,
        height: 60.0,
        items: <Widget>[
          Icon(Icons.home, size: 30, color: Colors.white),
          Icon(Icons.history, size: 30, color: Colors.white),
          Icon(Icons.settings, size: 30, color: Colors.white),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
