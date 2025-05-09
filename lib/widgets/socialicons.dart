import 'package:flutter/material.dart';

class SocialIconsWidget extends StatefulWidget {
  final int selectedIndex;

  const SocialIconsWidget({Key? key, required this.selectedIndex}) : super(key: key);

  @override
  _SocialIconsWidgetState createState() => _SocialIconsWidgetState();
}

class _SocialIconsWidgetState extends State<SocialIconsWidget> {
  bool _isSocialLoading = false;

  void _handleSocialSignIn() {
    setState(() {
      _isSocialLoading = true; // Start loading
    });

    // Simulate a network call or async task
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isSocialLoading = false; // Stop loading after completion
      });
      // Add actual social sign-in logic here
      debugPrint('Social loading completed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isSocialLoading
        ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _handleSocialSignIn, // A function to start social sign-in
                icon: Image.asset(
                  "assets/icon_google.png",
                  height: 40,
                  width: 40,
                ), // Google icon
                tooltip: widget.selectedIndex == 0 ? 'Sign in with Google' : 'Sign up with Google',
              ),
              SizedBox(width: 20),
              IconButton(
                onPressed: _handleSocialSignIn,
                icon: Image.asset(
                  "assets/icon_facebook.png",
                  height: 40,
                  width: 40,
                ),
                tooltip: widget.selectedIndex == 0 ? 'Sign in with Facebook' : 'Sign up with Facebook',
              ),
            ],
          );
  }
}
