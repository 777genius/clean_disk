import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design system stays independent from app, features, and DI', () {
    _expectNoImportsStartingWith(_collectImports('lib'), const <String>[
      'package:clean_disk_app',
      'package:clean_disk_scan',
      'package:get_it',
      'package:modularity_flutter',
      'package:mobx',
      'package:drift',
      'package:dio',
      'package:syncfusion',
    ]);
  });
}

void _expectNoImportsStartingWith(
  Set<String> actualImports,
  List<String> forbiddenPrefixes,
) {
  final forbiddenImports = actualImports.where((uri) {
    return forbiddenPrefixes.any(uri.startsWith);
  }).toList();

  expect(forbiddenImports, isEmpty);
}

Set<String> _collectImports(String directoryPath) {
  final directory = Directory(
    _resolveDirectoryPath(
      packageRelativePath: directoryPath,
      workspaceRelativePath: 'packages/design_system/$directoryPath',
    ),
  );
  final imports = <String>{};

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    for (final line in entity.readAsLinesSync()) {
      final normalized = line.trim();
      if (!normalized.startsWith('import ')) {
        continue;
      }

      final uri = _extractImportUri(normalized);
      if (uri != null) {
        imports.add(uri);
      }
    }
  }

  return imports;
}

String _resolveDirectoryPath({
  required String packageRelativePath,
  required String workspaceRelativePath,
}) {
  if (Directory(packageRelativePath).existsSync()) {
    return packageRelativePath;
  }

  return workspaceRelativePath;
}

String? _extractImportUri(String line) {
  final firstQuote = line.indexOf("'");
  if (firstQuote == -1) {
    return null;
  }

  final secondQuote = line.indexOf("'", firstQuote + 1);
  if (secondQuote == -1) {
    return null;
  }

  return line.substring(firstQuote + 1, secondQuote);
}
