import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('scan UI parts are complete and remain focused', () {
    final packageRoot = Directory('lib').existsSync()
        ? 'lib'
        : 'features/scan/lib';
    final base = '$packageRoot/src/presentation/pages';
    final entrypoint = File('$base/scan_home_page.dart');
    final rootSource = entrypoint.readAsStringSync();
    final declarations = RegExp(
      r"^part '([^']+)';$",
      multiLine: true,
    ).allMatches(rootSource).map((m) => m.group(1)!).toList();

    expect(declarations.length, greaterThanOrEqualTo(10));
    expect(declarations.toSet().length, declarations.length);
    // Keep the entrypoint small enough to review without hiding large state
    // machines inside it. Behavioral changes belong to separate tests.
    expect(rootSource.split('\n').length, lessThan(1000));

    for (final part in declarations) {
      final file = File('$base/$part');
      expect(file.existsSync(), isTrue, reason: 'Missing part: $part');
      final source = file.readAsStringSync();
      expect(
        source.startsWith("part of 'scan_home_page.dart';"),
        isTrue,
        reason: 'Incorrect library boundary: $part',
      );
      expect(
        source.split('\n').length,
        lessThan(1000),
        reason: 'Split oversized UI section instead of growing $part',
      );
    }
  });
}
