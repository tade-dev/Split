import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colour values live in lib/core/theme and nowhere else. A widget that
/// hardcodes one drifts from DESIGN.md the first time a token changes.
void main() {
  test('no widget hardcodes a colour value', () {
    final offences = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll(r'\', '/').contains('lib/core/theme/'))
        .where((f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Color\(\s*0x|Color\.fromARGB|Color\.fromRGBO').hasMatch(lines[i])) {
          offences.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offences, isEmpty, reason: 'Use a SplitColors token instead:\n${offences.join('\n')}');
  });
}
