import 'dart:math';

import '/views/login.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfilePage extends StatelessWidget {
  final _storage = FlutterSecureStorage();

  Future<Map<String, String>> _loadCredentials() async {
    String? email = await _storage.read(key: 'email');
    String? password = await _storage.read(key: 'password');

    if (email == null || password == null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        email = user.email;
        // Note: Firebase Auth does not provide a way to get the password directly.
        // You would need to store the password securely when the user logs in or signs up.
        // For this example, we'll assume the password is stored securely during login/signup.
        password = await _storage.read(key: 'password');
        if (email != null && password != null) {
          await _storage.write(key: 'email', value: email);
          await _storage.write(key: 'password', value: password);
        }
      }
    }

    return {
      'email': email ?? '',
      'password': password ?? '',
    };
  }

  Future<void> _logout(BuildContext context) async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      // No internet connection
      _showAlertDialog(context, "No internet connection. Please try again later.");
    } else {
      // Internet connection available
      await FirebaseAuth.instance.signOut();
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
  }

  void _showAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Profile', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, String>>(
        future: _loadCredentials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading credentials'));
          } else {
            final credentials = snapshot.data!;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 4,
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: EditableField(
                        label: 'Email',
                        initialValue: credentials['email']!,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => _logout(context),
                    child: Text('Logout', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class EditableField extends StatelessWidget {
  final String label;
  final String initialValue;

  EditableField({required this.label, required this.initialValue});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $initialValue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
