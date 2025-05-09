import 'package:flutter/material.dart';

Widget buildSocialDivider() {
  return Row(
    children: [
      Expanded(
        child: Divider(
          thickness: 0.5,
          color: Colors.grey[300], // Light grey color for the divider line
          endIndent: 10, // Space between the line and the "or" text
        ),
      ),
      Text("or", style: TextStyle(color: Colors.grey)),
      Expanded(
        child: Divider(
          thickness: 0.5,
          color: Colors.grey[300],
          indent: 10, // Space between the "or" text and the line
        ),
      ),
    ],
  );
}
