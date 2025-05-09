import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class HistoryPage extends StatefulWidget {
  final String deviceId;
  final String devicePass;
  final String uid;

  HistoryPage({required this.deviceId, required this.uid, required this.devicePass});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _currentIndex = 0;
  DateTime selectedDate = DateTime.now(); // Store the selected date
  List<String> userHistory = [];
  final databaseReference = FirebaseDatabase.instance.ref();
  final _storage = FlutterSecureStorage();
  String logData = "Loading log data...";
  String filteredLogData = ""; // Filtered log data
  WebSocketChannel? _channel; // Add this line

  @override
  void initState() {
    super.initState();

    // Fetch logs for the current date on page load
    String formattedDate = "${selectedDate.month}-${selectedDate.day}-${selectedDate.year}";
    fetchObstacleLogs(formattedDate);
  }

  @override
  void dispose() {
    _channel?.sink.close(); // Close the WebSocket connection
    super.dispose();
  }

  Future<void> fetchObstacleLogs(String date) async {
    try {
      // Normalize the date to match the log file format
      String normalizedDate = normalizeDate(date); // Convert "12-6-2024" to "12-06-2024"
      print("Searching for date: $normalizedDate");

      // Retrieve the user's devices from storage
      final devicesJson = await _storage.read(key: 'users_${widget.uid}_devices');
      print(widget.uid);

      if (devicesJson != null) {
        // Parse the user's devices
        List<Map<String, dynamic>> localDevices = List<Map<String, dynamic>>.from(jsonDecode(devicesJson));
        final device = localDevices.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => {});

        if (device.isNotEmpty) {
          String addDeviceConnection = device['addDeviceConnection'];
          print('Device ID: ${device['deviceId']}, Connection: $addDeviceConnection');

          if (addDeviceConnection == 'offline') {
            // Handle offline mode
            final url = Uri.http(widget.deviceId + ".local", "/download");
            final response = await http.get(url, headers: {
              'Authorization': 'Basic ' + base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}')),
            });

            if (response.statusCode == 200) {
              String responseBody = response.body;
              List<String> lines = responseBody.split('\n');

              // Normalize log lines by trimming spaces
              lines = lines.map((line) => line.trim()).toList();
              print("Searching for date: $normalizedDate in log lines:");
              lines.forEach(print);

              // Find the log line for the given date
              String? logLine = lines.firstWhere(
                (line) => line.startsWith(normalizedDate),
                orElse: () => '',
              );

              if (logLine.isNotEmpty) {
                // Map sensor names
                Map<String, String> sensorNames = {
                  'firstsensor': 'Counted Coconut',
                  'secondsensor': 'Counted Coconut',
                  'thirdsensor': 'Counted Coconut',
                };

                // Process log data
                List<String> logParts = logLine.split(' ');
                List<String> orderedLogs = logParts.sublist(1).map((part) {
                  List<String> keyValue = part.split('=');
                  return '${sensorNames[keyValue[0]]}: ${keyValue[1]}';
                }).toList();

                setState(() {
                  userHistory = orderedLogs;
                });
              } else {
                // No log line found for the date
                setState(() {
                  userHistory = ['No data found for the selected date'];
                });
              }
            } else {
              // Handle HTTP error
              setState(() {
                userHistory = ['No data found'];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${response.reasonPhrase}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Handle online mode
            try {
              String deviceID = widget.deviceId;
              DatabaseReference logsRef =
                  databaseReference.child('devices').child(deviceID).child('obstacle_logs').child(normalizedDate);
              DataSnapshot snapshot = await logsRef.get();

              if (snapshot.exists) {
                // Map sensor names
                Map<dynamic, dynamic> logs = snapshot.value as Map;
                Map<String, String> sensorNames = {
                  'firstSensor': 'Counted Coconut',
                  'secondSensor': 'Counted Coconut',
                  'thirdSensor': 'Counted Coconut',
                };

                // Order and process logs
                List<String> sensorOrder = ['firstSensor', 'secondSensor', 'thirdSensor'];
                List<String> orderedLogs = sensorOrder
                    .where((sensor) => logs.containsKey(sensor))
                    .map((sensor) => '${sensorNames[sensor]}: ${logs[sensor]}')
                    .toList();

                setState(() {
                  userHistory = orderedLogs;
                });
              } else {
                // No logs found in Firebase
                setState(() {
                  userHistory = ['No data found for the selected date'];
                });
              }
            } catch (error) {
              // Handle Firebase error
              setState(() {
                userHistory = ['No data found'];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    } catch (error) {
      // Handle unexpected errors
      setState(() {
        userHistory = ['No data found'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error check device connection ' + error.toString()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Function to normalize the date
  String normalizeDate(String date) {
    // Split the date into components
    List<String> dateParts = date.split('-'); // Expected input: MM-DD-YYYY

    // Zero-pad the month and day if necessary
    String month = dateParts[0].padLeft(2, '0'); // Ensures two digits for the month
    String day = dateParts[1].padLeft(2, '0'); // Ensures two digits for the day
    String year = dateParts[2]; // Year remains unchanged

    // Return the normalized date
    return '$month-$day-$year';
  }

  // Function to show the date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.brown, // Header background color
            colorScheme: ColorScheme.light(primary: Colors.brown, secondary: Colors.brown), // Header text color
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary), // Button text color
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      // Fetch logs for the selected date
      String formattedDate = "${selectedDate.month}-${selectedDate.day}-${selectedDate.year}";
      fetchObstacleLogs(formattedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  _selectDate(context); // Show date picker on tap
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.brown, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${selectedDate.month}/${selectedDate.day}/${selectedDate.year}",
                        style: TextStyle(fontSize: 18),
                      ),
                      Icon(Icons.calendar_today, color: Colors.brown),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: userHistory.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.history, color: Colors.brown),
                    title: Text(userHistory[index]),
                    subtitle:
                        Text(userHistory[0] == 'No data found for the selected date' ? 'Log' : 'Sensor ${index + 1}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
