import 'package:flutter/material.dart';

/// all nice, fitting colors usable for this app
const colors = [
  /*Color(0xFFF94144),*/ Color(0xFFF3722C), Color(0xFFF8961E), Color(0xFFF9C74F),   Color(0xFF90BE6D), Color(0xFF43AA8B), Color(0xFF577590),
  /*Colors.red,*/       Colors.deepOrange,   Colors.amber,      Colors.yellowAccent, Colors.green,    Colors.cyan,        Colors.blue,
];
/// Returns appropriate foreground/contrast color for the given color or null if it none of the app colors
Color? getForegroundForColor(Color c) {
  if (c.value == const Color(0xFFF94144).value || c.value == Colors.red.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF3722C).value || c.value == Colors.deepOrange.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF8961E).value || c.value == Colors.amber.value) {
    return Colors.white;
  } else if (c.value == const Color(0xFFF9C74F).value || c.value == Colors.yellowAccent.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF90BE6D).value || c.value == Colors.green.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF43AA8B).value) {
    return Colors.white;
  } else if (c.value == Colors.cyan.value) {
    return Colors.black;
  } else if (c.value == const Color(0xFF577590).value) {
    return Colors.white;
  } else if (c.value == Colors.blue.value) {
    return Colors.black;
  } else {
    return null;
  }
}