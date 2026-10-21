import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/firestore_time.dart';

part 'participant.freezed.dart';
part 'participant.g.dart';

/// organisers/{uid}/splits/{splitId}/participants/{id}. The fields the app
/// reads; the nudge fields of spec §2 join in Week C.
@freezed
abstract class Participant with _$Participant {
  const factory Participant({
    required String id,
    required String name,
    @Default(0) int colourIndex,
    @Default(false) bool isOrganiser,
    @Default(0) int joinOrder,
    @Default('invited') String status,
    int? shareMinor,

    /// What they typed on their link, verbatim. Null when they picked from
    /// the bill instead, or the organiser claimed for them.
    String? claimText,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? claimedAt,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? linkOpenedAt,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? paidAt,
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) => _$ParticipantFromJson(json);
}
