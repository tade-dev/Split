import 'package:freezed_annotation/freezed_annotation.dart';

part 'participant.freezed.dart';
part 'participant.g.dart';

/// organisers/{uid}/splits/{splitId}/participants/{id}. The fields Week A
/// reads; the payment and nudge fields of spec §2 join with the Tracker.
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
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) => _$ParticipantFromJson(json);
}
