import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

ValueNotifier<bool> isOnrelayNotifier = ValueNotifier<bool>(false);
String dataDeviceID = ''; // Initialize dataDeviceID

void setDataDeviceID(String deviceId) {
  dataDeviceID = deviceId;
  listenToRelayControl();
}

void listenToRelayControl() {
  if (dataDeviceID.isEmpty) return;

  // Define the dynamic path to relayControl using dataDeviceID
  final DatabaseReference relayControlRef = FirebaseDatabase.instance.ref('/devices/$dataDeviceID/relayControl');

  // Listen for changes at the relayControl path
  relayControlRef.onValue.listen((event) {
    final relayControlValue = event.snapshot.value;
    if (relayControlValue != null) {
      bool newValue = relayControlValue.toString().toLowerCase() == 'on';
      isOnrelayNotifier.value = newValue;
    }
  });
}
