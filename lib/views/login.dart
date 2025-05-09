import 'package:cohaco/dmanager.dart';

import '/views/devices.dart';
import '/widgets/dialogerror.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/widgets/divider.dart';
import '/widgets/roundedtextfield.dart';
import '/widgets/socialicons.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _emailsignup;
  late final TextEditingController _passwordsignup;
  late final TextEditingController _confirmpasswordsignup;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  int _selectedIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);

  bool _rememberMe = false;
  bool _isLoading = false; // Track loading state for Forgot Password
  bool _isLoadingf = false; // Track loading state for Forgot Password
  bool _isSignInLoading = false; // Loading for Login button
  bool _isSignUpLoading = false; // Loading for Create Account button
  bool _isSocialLoading = false;

  String? _signInEmail;
  String? _signInPassword;
  String? _signUpEmail;
  String? _signUpPassword;
  String? _signUpConfirmPassword;
  // Error messages for inline display
  String? _emailError;
  String? _passwordError;

  final _storage = FlutterSecureStorage();

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    _emailsignup = TextEditingController();
    _passwordsignup = TextEditingController();
    _confirmpasswordsignup = TextEditingController();

    _email.addListener(() {
      if (_emailError != null) {
        setState(() {
          _emailError = null;
        });
      }
    });

    _password.addListener(() {
      if (_passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    });
    // if not remembered, clear email and password
    _storage.read(key: 'remember_me').then((value) {
      if (value == 'false') {
        _storage.delete(key: 'email');
        _storage.delete(key: 'password');
        _storage.delete(key: 'remember_me');
        _storage.delete(key: 'user_token');
        _storage.delete(key: 'uid');
        _storage.delete(key: 'devices');
        _storage.delete(key: 'session_token');
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailsignup.dispose();
    _passwordsignup.dispose();
    _confirmpasswordsignup.dispose();
    super.dispose();
  }

  // Add this helper method to get token
  Future<String?> _getUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

// Update _validateAndCreateAccount method
  Future<void> _validateAndCreateAccount() async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailsignup.text,
        password: _passwordsignup.text,
      );

      final user = userCredential.user;
      if (user != null) {
        final token = await user.getIdToken();

        // Store user data in Firebase using UID
        final dbRef = FirebaseDatabase.instance.ref();
        await dbRef.child('users/${user.uid}').set({
          'uid': user.uid,
          'email': user.email,
          'token': token,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Store token and user info in secure storage
        await _storage.write(key: 'user_token', value: token);
        await _storage.write(key: 'uid', value: user.uid);
        await _storage.write(key: 'email', value: user.email);
      }

      setState(() => _isSignUpLoading = false);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Devices()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Error handling remains the same
      setState(() {
        _isSignUpLoading = false;
        if (e.code == 'email-already-in-use') {
          _emailError = "Email is already in use";
        } else if (e.code == 'invalid-email') {
          _emailError = "Invalid Email";
        } else if (e.code == 'weak-password') {
          _passwordError = "Password is too weak";
        } else {
          showAlertDialog(context, "${e.message}");
        }
      });
      _signUpFormKey.currentState?.validate();
    }
  }

// Update _validateAndLogin method
  Future<void> _validateAndLogin() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text,
        password: _password.text,
      );

      final user = userCredential.user;
      if (user != null) {
        final token = await user.getIdToken();

        final devices = await _fetchDevices(user.uid);
        if (_rememberMe) {
          await _storage.write(key: 'user_token', value: token);
          await _storage.write(key: 'uid', value: user.uid);
          await _storage.write(key: 'email', value: user.email);
          await _storage.write(key: 'remember_me', value: 'true');
          await _storage.write(key: 'devices', value: jsonEncode(devices));
          await _storage.write(key: 'users_${user.uid}_devices', value: jsonEncode(devices));
        } else {
          await _storage.write(key: 'session_token', value: token);
          await _storage.write(key: 'uid', value: user.uid);
          await _storage.write(key: 'email', value: user.email);
          await _storage.write(key: 'devices', value: jsonEncode(devices));
          await _storage.write(key: 'remember_me', value: 'false');
          await _storage.write(key: 'users_${user}_devices', value: jsonEncode(devices));
        }
        await DeviceManager.instance.initialize(user.uid);
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Devices()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle login errors
      setState(() {
        _isSignInLoading = false;
        if (e.code == 'invalid-email') {
          _emailError = "Invalid Email";
        } else if (e.code == 'user-not-found') {
          _emailError = "No user found with this email";
        } else if (e.code == 'wrong-password') {
          _passwordError = "Incorrect password";
        } else if (e.code == 'too-many-requests') {
          _emailError = "Too many requests, try again later";
        } else if (e.code == 'network-request-failed') {
          showAlertDialog(context, "Network error, please try again.");
        } else {
          showAlertDialog(context, "${e.message}");
        }
      });
      _signInFormKey.currentState?.validate();
    } catch (e) {
      // Handle unexpected errors
      setState(() {
        _isSignInLoading = false;
        showAlertDialog(context, e.toString());
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDevices(String uid) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child('users/$uid/devices').get();

    if (snapshot.exists) {
      final Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
      return values.entries.map((entry) {
        final Map<String, dynamic> device = Map<String, dynamic>.from(entry.value as Map);
        device['deviceId'] = entry.key;
        print(device);
        return device;
      }).toList();
    } else {
      return [];
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: 'email', value: _email.text);
      await _storage.write(key: 'password', value: _password.text);
    } else {
      await _storage.delete(key: 'email');
      await _storage.delete(key: 'password');
    }
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController emailController = TextEditingController();
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email to receive a password reset link.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          String email = emailController.text.trim();

                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an email.')),
                            );
                            return;
                          }

                          setDialogState(() => isSending = true);

                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Password reset link sent to $email.')),
                            );
                            Navigator.pop(context);
                          } catch (error) {
                            //user-not-found
                            if (error.toString().contains('user-not-found')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No user found with this email.')),
                              );
                            } else if (error.toString().contains('invalid-email')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid email.')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('An error occurred. Please try again later.')),
                              );
                            }
                            Navigator.pop(context);
                          } finally {
                            setDialogState(() => isSending = false);
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _login() {
    // Validate form first
    if (!_signInFormKey.currentState!.validate()) {
      // Stop if validation fails
      return;
    }

    // If validation passes, save form and proceed to Firebase login
    _signInFormKey.currentState!.save();

    // Show loading indicator
    setState(() {
      _isSignInLoading = true;
      _emailError = null;
      _passwordError = null;
    });

    // Attempt Firebase login
    _validateAndLogin();
  }

  void _createAccount() {
    if (!_signUpFormKey.currentState!.validate()) {
      // Stop if validation fails
      return;
    }

    // If validation passes, save form and proceed to Firebase account creation
    _signUpFormKey.currentState!.save();

    // Show loading indicator
    setState(() {
      _isSignUpLoading = true;
      _emailError = null;
      _passwordError = null;
    });

    // Attempt Firebase account creation
    _validateAndCreateAccount();
  }

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Cohaco',
          style: TextStyle(
            fontSize: 35,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10.0),
            width: 400,
            height: 430,
            decoration: BoxDecoration(
              color: Colors.white,
              // borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom Tab Row
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.brown[100],
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _onTabChange(0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 69.5),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 0 ? Colors.brown : Colors.transparent,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: _selectedIndex == 0 ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onTabChange(1),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 69.5),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 1 ? Colors.brown : Colors.transparent,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: _selectedIndex == 1 ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    children: [
                      // Sign In Form
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Form(
                          key: _signInFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              RoundedTextField(
                                controller: _email,
                                label: 'Email',
                                icon: Icons.email,
                                obscureText: false,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  //firebase auth error
                                  else if (_emailError != null) {
                                    return "$_emailError";
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _signInEmail = value;
                                },
                              ),
                              SizedBox(height: 10),
                              // Sign In Password Field
                              RoundedTextField(
                                controller: _password,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  //firebase auth error
                                  else if (_passwordError != null) {
                                    return "$_passwordError";
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _signInPassword = value;
                                },
                                isPasswordField: true,
                              ),
                              SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isSignInLoading ? null : _login,
                                child: _isSignInLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : Text('Login'),
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _rememberMe = !_rememberMe;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value!;
                                            });
                                          },
                                          activeColor: Colors.brown,
                                        ),
                                        Text('Remember Me'),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _forgotPassword,
                                    style: const ButtonStyle(
                                      overlayColor: WidgetStatePropertyAll(Colors.transparent), // Remove hover effect
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(color: Colors.brown),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Sign Up Form
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Form(
                          key: _signUpFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              RoundedTextField(
                                controller: _emailsignup,
                                label: 'Email',
                                icon: Icons.email,
                                obscureText: false,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  } else if (_emailError != null) {
                                    return "$_emailError";
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _signUpEmail = value;
                                },
                              ),
                              SizedBox(height: 10),
                              // Sign Up Password Field
                              RoundedTextField(
                                controller: _passwordsignup,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _signUpPassword = value;
                                },
                                isPasswordField: true,
                              ),
                              SizedBox(height: 10),
                              RoundedTextField(
                                controller: _confirmpasswordsignup,
                                label: 'Confirm Password',
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  } else if (value != _passwordsignup.text) {
                                    return 'Passwords do not match';
                                  } else if (_passwordError != null) {
                                    return "$_passwordError";
                                  }

                                  return null;
                                },
                                onSaved: (value) {
                                  _signUpConfirmPassword = value;
                                },
                                isPasswordField: true,
                              ),
                              SizedBox(height: 20),
                              // Create Account Button with loading indicator
                              ElevatedButton(
                                onPressed: _isSignUpLoading ? null : _createAccount,
                                child: _isSignUpLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : Text('Create Account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
