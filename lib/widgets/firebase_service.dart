import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _database;

  FirebaseService(String deviceId)
      : _database = FirebaseDatabase.instance.ref().child('devices/$deviceId/relayControl');

  Future<bool> fetchRelayControlStatus() async {
    final snapshot = await _database.get();
    if (snapshot.exists) {
      return snapshot.value.toString().toLowerCase() == 'on';
    }
    return false;
  }

  Future<void> updateRelayControlStatus(bool isOn) async {
    await _database.set(isOn ? 'on' : 'off');
  }

  Stream<bool> get relayControlStream {
    return _database.onValue.map((event) {
      if (event.snapshot.value != null) {
        return event.snapshot.value.toString().toLowerCase() == 'on';
      }
      return false;
    });
  }
}
