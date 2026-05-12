import 'package:flutter/material.dart';

Color parseHexColour(String hexColor) {
  var hex = hexColor.toUpperCase().replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

IconData materialIconFromCodePoint(int codePoint) =>
    IconData(codePoint, fontFamily: 'MaterialIcons');

/// Tinted circle + solid icon colour (colour mix) for category glyphs.
Widget categoryGlyphAvatar({
  required Color colour,
  required int iconCodePoint,
  double radius = 20,
}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: colour.withValues(alpha: 0.22),
    child: Icon(
      materialIconFromCodePoint(iconCodePoint),
      color: colour,
      size: radius * 1.1,
    ),
  );
}
