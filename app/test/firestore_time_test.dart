import 'package:flutter_test/flutter_test.dart';
import 'package:split/core/firestore_time.dart';

class _Stamp {
  _Stamp(this.value);
  final DateTime value;
  DateTime toDate() => value;
}

void main() {
  test('reads ISO strings, epoch maps and Timestamp-like values', () {
    expect(
      dateTimeFromJson('2026-10-10T11:02:00.000Z'),
      DateTime.utc(2026, 10, 10, 11, 2),
    );
    expect(
      dateTimeFromJson({'_seconds': 1760090520, '_nanoseconds': 0}),
      DateTime.fromMillisecondsSinceEpoch(1760090520 * 1000, isUtc: true),
    );
    final stamp = DateTime.utc(2026, 10, 10, 11, 31);
    expect(dateTimeFromJson(_Stamp(stamp)), stamp);
    expect(dateTimeFromJson(null), isNull);
    expect(dateTimeFromJson('not-a-date'), isNull);
  });

}
