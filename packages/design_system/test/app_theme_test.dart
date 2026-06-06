import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless/headless.dart';

void main() {
  test('light theme uses Material 3', () {
    expect(AppTheme.light().useMaterial3, isTrue);
  });

  test('dark theme uses Material 3 and dark brightness', () {
    final theme = AppTheme.dark();

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });

  test('light theme uses the app Figma font family', () {
    final theme = AppTheme.light();

    expect(theme.textTheme.bodyMedium?.fontFamily, contains('Involve'));
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, isNull);
  });

  test('headless theme is created from app Material theme data', () {
    final headlessTheme = AppHeadlessTheme.fromThemeData(AppTheme.dark());

    expect(headlessTheme.capability<RButtonRenderer>(), isNotNull);
    expect(headlessTheme.capability<RDropdownButtonRenderer>(), isNotNull);
    expect(headlessTheme.capability<RTextFieldRenderer>(), isNotNull);
  });
}
