import 'package:freezed_annotation/freezed_annotation.dart';

part 'ambiguity.freezed.dart';
part 'ambiguity.g.dart';

/// Something the organiser has to decide. Blocking ones come from code
/// checking the numbers; the model's own questions arrive as non-blocking
/// notes. The API words `question` for the screen, so it is shown verbatim.
@freezed
abstract class Ambiguity with _$Ambiguity {
  const factory Ambiguity({
    required String field,
    required String kind,
    required String question,
    @Default(<String>[]) List<String> options,
    @Default(true) bool blocking,
  }) = _Ambiguity;

  factory Ambiguity.fromJson(Map<String, dynamic> json) => _$AmbiguityFromJson(json);
}
