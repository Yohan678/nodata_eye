import 'package:flutter/material.dart';

class ToggleWidget extends StatelessWidget {
  const ToggleWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.activeColor = Colors.green,
    this.activeTrackColor = const Color(0xFFB9F6CA),
    this.inactiveTrackColor = const Color(0xFF3A3A3C),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final Color activeColor;
  final Color activeTrackColor;
  final Color inactiveTrackColor;

  @override
  Widget build(BuildContext context) {
    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
      activeTrackColor: activeTrackColor,
      inactiveTrackColor: inactiveTrackColor,
      inactiveThumbColor: Colors.white,
    );

    if (label == null) {
      return switchWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        switchWidget,
      ],
    );
  }
}