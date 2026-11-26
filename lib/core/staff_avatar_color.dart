import 'package:material_ui/material_ui.dart';

Color staffAvatarColor(int id) {
  final hue = (id * 137.508) % 360;
  return HSVColor.fromAHSV(1, hue, 0.65, 0.75).toColor();
}
