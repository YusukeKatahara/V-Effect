import 'package:flutter/material.dart';

void main() {
  RadioGroup<String>(
    groupValue: 'A',
    onChanged: (v) {},
    child: Column(
      children: [
        Radio<String>(value: 'A'),
      ]
    )
  );
}
