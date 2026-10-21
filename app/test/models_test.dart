import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split/models/organiser.dart';
import 'package:split/models/participant.dart';
import 'package:split/models/split.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

class _Stamp {
  _Stamp(this.value);
  final DateTime value;
  DateTime toDate() => value;
}

void main() {
  group('SplitDoc', () {
    // Captured from POST /v1/splits/scan against the emulator: Lager was
    // misread as £15.60, so the bill does not add up.
    final scanned = SplitDoc.fromJson(_fixture('scan-response.json')['split'] as Map<String, dynamic>);

    test('parses the scan response the API really sends', () {
      expect(scanned.status, 'draft');
      expect(scanned.title, "Friday's bill");
      expect(scanned.merchant, 'Little Bao House');
      expect(scanned.receipt.lines, hasLength(10));
      expect(scanned.receipt.lines[8].id, 'lager-8');
      expect(scanned.receipt.lines[8].qty, 3);
      expect(scanned.receipt.printedTotalMinor, 15469);
      expect(scanned.receipt.serviceChargeLabel, '12.5% discretionary');
      expect(scanned.computed!.ok, isFalse);
      expect(scanned.computed!.problems, isNotEmpty);
    });

    test('separates blocking problems from the model\'s notes', () {
      expect(scanned.blocking.single.kind, 'price_conflict');
      expect(scanned.blocking.single.question, startsWith('Items add up to £153.79'));
      expect(scanned.notes.single.field, 'lines.lager-8.qty');
    });

    test('keeps an unread price and total as null, never 0', () {
      final split = SplitDoc.fromJson({
        'id': 's1',
        'receipt': {
          'lines': [{'id': 'lager-0', 'name': 'Lager', 'qty': 3, 'lineTotalMinor': null}],
          'printedTotalMinor': null,
        },
      });
      expect(split.receipt.lines.single.lineTotalMinor, isNull);
      expect(split.receipt.printedTotalMinor, isNull);
    });

    test('reads Firestore timestamps as well as ISO strings', () {
      final at = DateTime.utc(2026, 10, 2, 20, 41);
      expect(SplitDoc.fromJson({'id': 's1', 'createdAt': _Stamp(at)}).createdAt, at);
      expect(SplitDoc.fromJson({'id': 's1', 'createdAt': '2026-10-02T20:41:00.000Z'}).createdAt, at);
    });

    test('knows which statuses are still open', () {
      expect(const SplitDoc(id: 'a').isOpen, isTrue);
      expect(const SplitDoc(id: 'a', status: 'settled').isOpen, isFalse);
      expect(const SplitDoc(id: 'a', status: 'cancelled').isOpen, isFalse);
    });
  });

  test('Computed parses an ok allocation with every breakdown', () {
    // allocate() over samples/demo-split.json, serialised.
    final c = Computed.fromJson(_fixture('computed-ok.json'));
    expect(c.ok, isTrue);
    expect(c.totalMinor, 15469);
    expect(c.perParticipant['dan']!.finalMinor, 3923);
    expect(c.perParticipant['sam']!.sharedFromOnUsMinor, -2910);
    final lager = c.perParticipant['josh']!.lines.firstWhere((l) => l.lineId == 'lager-8');
    expect((lager.minor, lager.portionLabel), (1100, '2 of 3'));
  });

  test('Participant and Organiser read their Firestore shape', () {
    final p = Participant.fromJson({'id': 'p1', 'name': 'Kemi', 'colourIndex': 0, 'isOrganiser': true, 'joinOrder': 0, 'status': 'invited', 'shareMinor': null});
    expect((p.name, p.isOrganiser, p.shareMinor), ('Kemi', true, null));
    final o = Organiser.fromJson({'id': 'kemi', 'displayName': 'Kemi', 'paypalEmail': null, 'demoSeeded': true});
    expect(o.displayName, 'Kemi');
  });

  test("reads claims in Week B's shape and Week A's bare lists", () {
    final split = SplitDoc.fromJson({
      'id': 's1',
      'claims': {
        'lager-8': {
          'claims': [{'participantId': 'josh', 'weight': 1, 'source': 'friend'}],
          'shared': true,
        },
        'prawn-crackers-0': [{'participantId': 'kemi', 'weight': 1, 'source': 'ai'}],
      },
    });
    expect(split.claims['lager-8'], const LineClaims(claims: [Claim(participantId: 'josh', source: 'friend')], shared: true));
    expect(split.claims['prawn-crackers-0'], const LineClaims(claims: [Claim(participantId: 'kemi', source: 'ai')]));
  });
}
