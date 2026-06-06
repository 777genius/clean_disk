import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('scan feature keeps framework imports at the correct boundaries', () {
    final importsByFile = _collectImportsByFile('lib');

    for (final entry in importsByFile.entries) {
      final path = entry.key;
      final imports = entry.value;
      final isDiFile = path.contains('/src/di/');
      final isPresentationFile = path.contains('/src/presentation/');
      final isPresentationStoreFile = path.contains(
        '/src/presentation/stores/',
      );
      final isDomainOrApplicationFile =
          path.contains('/src/domain/') || path.contains('/src/application/');

      if (!isDiFile) {
        _expectNoImportsStartingWith(path, imports, const <String>[
          'package:modularity_flutter',
        ]);
      }

      if (isDomainOrApplicationFile) {
        _expectNoImportsStartingWith(path, imports, const <String>[
          'package:abstract_http_client',
          'package:clean_disk_cache',
          'package:clean_disk_scan/src/data/',
          'package:file_selector',
          'package:flutter',
          'dart:convert',
          'dart:io',
        ]);
      }

      if (!isPresentationStoreFile) {
        _expectNoImportsStartingWith(path, imports, const <String>[
          'package:mobx',
        ]);
      }

      if (isPresentationFile) {
        _expectNoImportsStartingWith(path, imports, const <String>[
          'package:abstract_http_client',
          'package:clean_disk_cache',
          'package:clean_disk_scan/src/data/',
          'package:file_selector',
          'dart:io',
        ]);
      }

      _expectNoImportsStartingWith(path, imports, const <String>[
        'package:clean_disk_cache',
        'package:file_selector',
        'package:get_it',
        'package:headless',
      ]);
    }
  });

  test('scan feature keeps daemon route strings inside data sources', () {
    final routeLeaks = _collectFilesContaining(
      'lib',
      '/v1/',
    ).where((path) => !path.contains('/src/data/sources/')).toList();

    expect(routeLeaks, isEmpty);
  });

  test('scan feature keeps platform reveal commands out of feature code', () {
    final commandLeaks = <String>[
      ..._collectFilesContaining('lib', '/usr/bin/open'),
      ..._collectFilesContaining('lib', 'explorer.exe'),
      ..._collectFilesContaining('lib', 'xdg-open'),
    ];

    expect(commandLeaks, isEmpty);
  });
}

void _expectNoImportsStartingWith(
  String path,
  Set<String> actualImports,
  List<String> forbiddenPrefixes,
) {
  final forbiddenImports = actualImports.where((uri) {
    return forbiddenPrefixes.any(uri.startsWith);
  }).toList();

  expect(forbiddenImports, isEmpty, reason: path);
}

List<String> _collectFilesContaining(String directoryPath, String pattern) {
  final directory = Directory(
    _resolveDirectoryPath(
      packageRelativePath: directoryPath,
      workspaceRelativePath: 'features/scan/$directoryPath',
    ),
  );
  final matches = <String>[];

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    if (entity.readAsStringSync().contains(pattern)) {
      matches.add(entity.path);
    }
  }

  return matches;
}

Map<String, Set<String>> _collectImportsByFile(String directoryPath) {
  final directory = Directory(
    _resolveDirectoryPath(
      packageRelativePath: directoryPath,
      workspaceRelativePath: 'features/scan/$directoryPath',
    ),
  );
  final importsByFile = <String, Set<String>>{};

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    final imports = <String>{};
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
    importsByFile[entity.path] = imports;
  }

  return importsByFile;
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
