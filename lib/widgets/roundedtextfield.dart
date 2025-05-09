import 'package:flutter/material.dart';

class RoundedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final FormFieldValidator<String> validator;
  final ValueChanged<String?> onSaved;
  final bool isPasswordField;

  const RoundedTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.obscureText,
    required this.validator,
    required this.onSaved,
    this.isPasswordField = false,
  }) : super(key: key);

  @override
  _RoundedTextFieldState createState() => _RoundedTextFieldState();
}

class _RoundedTextFieldState extends State<RoundedTextField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return _buildRoundedTextField(
      controller: widget.controller,
      label: widget.label,
      icon: widget.icon,
      obscureText: widget.obscureText,
      validator: widget.validator,
      onSaved: widget.onSaved,
      isPasswordField: widget.isPasswordField,
    );
  }

  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required FormFieldValidator<String> validator,
    required ValueChanged<String?> onSaved,
    bool isPasswordField = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.brown),
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.brown,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
      ),
      obscureText: isPasswordField ? _obscurePassword : obscureText,
      validator: validator,
      onSaved: onSaved,
    );
  }
}
