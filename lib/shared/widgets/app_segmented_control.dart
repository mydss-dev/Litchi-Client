import 'package:flutter/material.dart';

@immutable
class AppSegmentedItem<T> {
  const AppSegmentedItem({required this.value, required this.label});

  final T value;
  final String label;
}
