import 'dart:async';

import 'package:cohaco/views/addDevice.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeView extends StatefulWidget {
  final String deviceId;
  final String devicePass;
  final String uid;

  HomeView({required this.deviceId, required this.devicePass, required this.uid});

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool isLoading = false;
  bool isRelayOn = false;
  final _storage = FlutterSecureStorage();
  Map<String, String> sensorData = {
    'Small Coconut': '0',
    'Medium Coconut': '0',
    'Large Coconut': '0',
  };
  String logData = '';
  String filteredLogData = '';
  DateTime selectedLogDate = DateTime.now();
  Timer? _timer;
  WebSocketChannel? _channel;
  StreamController<Map<String, String>> _sensorDataController = StreamController<Map<String, String>>.broadcast();

  @override
  void initState() {
    super.initState();

    setDataDeviceID(widget.deviceId);
    _fetchInitialRelayControlStatus();
    _startSensorDataStream();
    _startPollingRelayState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.sink.close();
    _sensorDataController.close(); // Close the StreamController
    super.dispose();
  }

  void _initializeWebSocket() {
    if (_channel == null) {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://${widget.deviceId}.local:8080'),
      );
    }
  }

  void _startSensorDataStream() {
    _sensorDataStream().listen((data) {
      _sensorDataController.add(data);
    });
  }

  void _startLogDataFetchTimer() {
    print("start timer ");
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchLogData();
    });
  }

  void _startPollingRelayState() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      getstatus();
    });
  }

  Future<void> fetchLogData() async {
    final url = Uri.http(widget.deviceId + ".local", "/data");
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Basic ' + base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}')),
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        logData = response.body;
        filterLogData(); // Filter log data after fetching it
      });
    } else {
      setState(() {
        logData = 'Failed to fetch log data';
        filteredLogData = ''; // Clear the filtered log data
      });
    }
  }

  void filterLogData() {
    print('selectedLogDate: $selectedLogDate');
    final dateString = DateFormat('MM-dd-yyyy').format(selectedLogDate);

    // Assuming log data is in a new-line-separated string format with a date prefix, e.g., "10-12-2024 Log message"
    List<String> logs = logData.split('\n');

    // Filter logs based on selected date
    List<String> filteredLogs = logs.where((log) {
      return log.startsWith(dateString);
    }).toList();

    setState(() {
      filteredLogData = filteredLogs.join('\n'); // Display filtered logs
    });
  }

  Future<void> _fetchInitialRelayControlStatus() async {
    setState(() => isLoading = true); // Start loading
    try {
      final deviceDataJson = await _storage.read(key: 'users_${widget.uid}_devices');
      if (deviceDataJson != null) {
        final List<dynamic> deviceDataList = jsonDecode(deviceDataJson);
        final deviceData =
            deviceDataList.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => null);

        if (deviceData != null) {
          final addDeviceConnection = deviceData['addDeviceConnection'];

          if (addDeviceConnection == 'online') {
            final DatabaseReference relayControlRef =
                FirebaseDatabase.instance.ref('/devices/${widget.deviceId}/relayControl');
            final snapshot = await relayControlRef.get();
            if (snapshot.exists) {
              bool initialStatus = snapshot.value.toString().toLowerCase() == 'on';
              isOnrelayNotifier.value = initialStatus;
            }
          } else if (addDeviceConnection == 'offline') {
            final url = Uri.http(widget.deviceId + ".local", "/getRelayState");
            final response = await http.get(
              url,
              headers: {
                'Authorization': 'Basic ' + base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}')),
              },
            );

            if (response.statusCode == 200) {
              setState(() {
                isOnrelayNotifier.value = response.body == 'on'; // Update based on the response
              });
              print('Fetched relay state: ${response.body}');
            } else {
              print('Failed to fetch relay state: ${response.body}');
            }
          }
        } else {
          print('Device not found');
        }
      } else {
        print('Failed to read device data from storage');
      }
    } catch (error) {
      print('Error fetching initial relay control status: $error');
    } finally {
      setState(() => isLoading = false); // End loading
    }
  }

  Future<void> getstatus() async {
    try {
      final deviceDataJson = await _storage.read(key: 'users_${widget.uid}_devices');
      if (deviceDataJson != null) {
        final List<dynamic> deviceDataList = jsonDecode(deviceDataJson);
        final deviceData =
            deviceDataList.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => null);

        if (deviceData != null) {
          final addDeviceConnection = deviceData['addDeviceConnection'];

          if (addDeviceConnection == 'online') {
            final DatabaseReference relayControlRef =
                FirebaseDatabase.instance.ref('/devices/${widget.deviceId}/relayControl');
            final snapshot = await relayControlRef.get();
            if (snapshot.exists) {
              bool initialStatus = snapshot.value.toString().toLowerCase() == 'on';
              isOnrelayNotifier.value = initialStatus;
            }
          } else if (addDeviceConnection == 'offline') {
            final url = Uri.http(widget.deviceId + ".local", "/getRelayState");
            final response = await http.get(
              url,
              headers: {
                'Authorization': 'Basic ' + base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}')),
              },
            );

            if (response.statusCode == 200) {
              setState(() {
                isOnrelayNotifier.value = response.body == 'on'; // Update based on the response
              });
              print('Fetched relay state: ${response.body}');
            } else {
              print('Failed to fetch relay state: ${response.body}');
            }
          }
        } else {
          print('Device not found');
        }
      } else {
        print('Failed to read device data from storage');
      }
    } catch (error) {
      print('Error fetching initial relay control status: $error');
    }
  }

  void toggleSwitch() async {
    final deviceDataJson = await _storage.read(key: 'users_${widget.uid}_devices');
    if (deviceDataJson != null) {
      final List<dynamic> deviceDataList = jsonDecode(deviceDataJson);
      final deviceData =
          deviceDataList.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => null);

      if (deviceData != null) {
        final addDeviceConnection = deviceData['addDeviceConnection'];

        if (addDeviceConnection == 'online') {
          print("online");
          final newState = !isOnrelayNotifier.value;
          // Update Firebase
          final DatabaseReference relayControlRef =
              FirebaseDatabase.instance.ref('/devices/${widget.deviceId}/relayControl');
          relayControlRef.set(newState ? 'on' : 'off').then((_) {
            isOnrelayNotifier.value = newState;
          }).catchError((error) {
            // Handle error
            print('Error updating relay control: $error');
          });
        } else if (addDeviceConnection == 'offline') {
          print("offline");
          await _toggleRelayViaHttp();
        } else {
          print('Unknown device connection state: $addDeviceConnection');
        }
      } else {
        print('Device not found');
      }
    } else {
      print('Failed to read device data from storage');
    }
  }

  Future<void> _toggleRelayViaHttp() async {
    final url = Uri.http(widget.deviceId + ".local", "/relay");
    final state = isOnrelayNotifier.value ? "off" : "on"; // Toggle between on and off
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Basic ' + base64Encode(utf8.encode('${widget.deviceId}:${widget.devicePass}')),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'state': state},
    );

    if (response.statusCode == 200) {
      setState(() {
        isOnrelayNotifier.value = !isOnrelayNotifier.value;
      });
      print('Relay toggled successfully to $state');
    } else {
      print('Failed to toggle relay: ${response.body}');
      throw Exception('Failed to toggle relay');
    }
  }

  void _showDeviceOfflineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Device Offline'),
          content: Text('The device is offline. Please check the connection and try again.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Stream<Map<String, String>> _sensorDataStream() async* {
    final deviceDataJson = await _storage.read(key: 'users_${widget.uid}_devices');

    if (deviceDataJson != null) {
      final List<dynamic> deviceDataList = jsonDecode(deviceDataJson);
      final deviceData =
          deviceDataList.firstWhere((device) => device['deviceId'] == widget.deviceId, orElse: () => null);
      if (deviceData != null) {
        final addDeviceConnection = deviceData['addDeviceConnection'];
        if (addDeviceConnection == 'online') {
          final DatabaseReference logsRef = FirebaseDatabase.instance.ref('/devices/${widget.deviceId}/obstacle_logs');

          // Get the latest date
          final DataSnapshot snapshot = await logsRef.orderByKey().limitToLast(1).get();
          if (!snapshot.exists || snapshot.children.isEmpty) {
            yield {
              'Small Coconut': '0',
              'Medium Coconut': '0',
              'Large Coconut': '0',
            };
            return;
          }

          final String latestDate = snapshot.children.first.key!;
          final DatabaseReference sensorsRef = logsRef.child(latestDate);

          yield* sensorsRef.onValue.map((event) {
            if (event.snapshot.value == null) {
              return {
                'Small Coconut': '0',
                'Medium Coconut': '0',
                'Large Coconut': '0',
              };
            }
            final sensorValues = event.snapshot.value as Map<dynamic, dynamic>;
            return {
              'Small Coconut': sensorValues['firstSensor']?.toString() ?? '0',
              'Medium Coconut': sensorValues['secondSensor']?.toString() ?? '0',
              'Large Coconut': sensorValues['thirdSensor']?.toString() ?? '0',
            };
          });
        } else if (addDeviceConnection == 'offline') {
          // Ensure the WebSocket connection is initialized
          _initializeWebSocket();

          // Listen for WebSocket data
          await for (final event in _channel!.stream) {
            try {
              // Parse the incoming data
              final data = event.toString();
              final parts = data.split(',');
              if (parts.length < 3) {
                throw FormatException('Invalid data format');
              }

              yield {
                'Small Coconut': parts[0],
                'Medium Coconut': parts[1],
                'Large Coconut': parts[2],
              };
            } catch (e) {
              print('Error parsing WebSocket data: $e');
              yield {
                'Small Coconut': '0',
                'Medium Coconut': '0',
                'Large Coconut': '0',
              };
            }
          }
        } else {
          yield {
            'Small Coconut': '0',
            'Medium Coconut': '0',
            'Large Coconut': '0',
          };
        }
      } else {
        yield {
          'Small Coconut': '0',
          'Medium Coconut': '0',
          'Large Coconut': '0',
        };
      }
    } else {
      yield {
        'Small Coconut': '0',
        'Medium Coconut': '0',
        'Large Coconut': '0',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Solid green background
          Container(
            color: Colors.brown,
            height: double.infinity,
            width: double.infinity,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.75,
              widthFactor: 1.0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6.0,
                      spreadRadius: 2.0,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: isLoading
                    ? Center(child: CircularProgressIndicator()) // Loading indicator
                    : buildDeviceContent(),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0.0, -0.6),
            child: isLoading
                ? Container() // Hide switch during loading
                : GestureDetector(
                    onTap: toggleSwitch,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isOnrelayNotifier,
                      builder: (context, isOn, child) {
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          width: 100.0,
                          height: 100.0,
                          decoration: BoxDecoration(
                            color: isOn ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 10.0,
                                spreadRadius: 2.0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                CupertinoIcons.power,
                                key: ValueKey(isOn ? "onIcon" : "offIcon"),
                                color: Colors.white,
                                size: 50.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to build device content
  Widget buildDeviceContent() {
    return StreamBuilder<Map<String, String>>(
      stream: _sensorDataController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(child: Text('No data available'));
        } else {
          final sensorData = snapshot.data!;
          return Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.08,
              bottom: MediaQuery.of(context).size.height * 0.05,
            ),
            child: ListView(
              children: [
                buildGreenBox(
                    child: buildText('Overall Harvested',
                        '${int.parse(sensorData['Small Coconut']!) + int.parse(sensorData['Medium Coconut']!) + int.parse(sensorData['Large Coconut']!)}')),
                SizedBox(height: 10),
                buildGreenBox(child: buildText('Small Coconut', sensorData['Small Coconut']!)),
                SizedBox(height: 10),
                buildGreenBox(child: buildText('Medium Coconut', sensorData['Medium Coconut']!)),
                SizedBox(height: 10),
                buildGreenBox(child: buildText('Large Coconut', sensorData['Large Coconut']!)),
              ],
            ),
          );
        }
      },
    );
  }

  // Helper to avoid repetitive code
  Widget buildText(String title, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.normal),
        ),
        SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(fontSize: 30.0, fontStyle: FontStyle.normal),
        ),
      ],
    );
  }

  // Updated buildGreenBox method to handle flexible sizing
  Widget buildGreenBox({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10), // Ensures consistent padding
      decoration: BoxDecoration(
        color: const Color.fromARGB(60, 214, 214, 214),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: child,
    );
  }
}
