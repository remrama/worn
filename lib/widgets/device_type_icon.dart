import 'package:flutter/material.dart';
import '../models/device.dart';

/// Renders the icon for a [DeviceType] in a square of [size].
///
/// Material glyphs sit inside a 20/24 live area of their em box, while Font
/// Awesome glyphs fill the whole box and look oversized next to them. Font
/// Awesome glyphs are drawn at [fontAwesomeScale] of [size] so all device
/// icons share one visual weight and footprint.
class DeviceTypeIcon extends StatelessWidget {
  const DeviceTypeIcon(this.type, {super.key, this.size});

  final DeviceType type;

  /// Box size; defaults to the ambient [IconTheme] size.
  final double? size;

  static const double fontAwesomeScale = 20 / 24;

  @override
  Widget build(BuildContext context) {
    final icon = Device.iconFor(type);
    final boxSize = size ?? IconTheme.of(context).size ?? 24;
    if (icon.fontPackage != 'font_awesome_flutter') {
      return Icon(icon, size: boxSize);
    }
    return SizedBox.square(
      dimension: boxSize,
      child: Center(child: Icon(icon, size: boxSize * fontAwesomeScale)),
    );
  }
}
