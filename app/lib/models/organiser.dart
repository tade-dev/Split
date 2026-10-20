import 'package:freezed_annotation/freezed_annotation.dart';

part 'organiser.freezed.dart';
part 'organiser.g.dart';

/// organisers/{uid}. Read from Firestore; written only by the API.
@freezed
abstract class Organiser with _$Organiser {
  const factory Organiser({
    required String id,

    /// The name friends see: "Kemi".
    @Default('') String displayName,

    /// Where friends' payments go. Null pays the shared sandbox merchant.
    String? paypalEmail,
  }) = _Organiser;

  factory Organiser.fromJson(Map<String, dynamic> json) => _$OrganiserFromJson(json);
}
