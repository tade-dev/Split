import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/firestore_time.dart';
import 'ambiguity.dart';
import 'receipt.dart';

part 'split.freezed.dart';
part 'split.g.dart';

@freezed
abstract class Claim with _$Claim {
  const factory Claim({
    required String participantId,
    @Default(1) int weight,
    @Default('organiser') String source,
  }) = _Claim;

  factory Claim.fromJson(Map<String, dynamic> json) => _$ClaimFromJson(json);
}

/// Everything claimed on one line. `shared` is the organiser's "Share between
/// …" answer to a line whose claims fall short of its quantity (spec Q1).
@freezed
abstract class LineClaims with _$LineClaims {
  const factory LineClaims({
    @Default(<Claim>[]) List<Claim> claims,
    @Default(false) bool shared,
  }) = _LineClaims;

  factory LineClaims.fromJson(Map<String, dynamic> json) => _$LineClaimsFromJson(json);
}

/// Week A stored a bare list per line; Week B wraps it. Reads accept both, as
/// the API's normaliseClaims does.
Map<String, LineClaims> claimsFromJson(Object? json) {
  if (json is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key as String: value is List
          ? LineClaims(claims: [for (final c in value) Claim.fromJson(Map<String, dynamic>.from(c as Map))])
          : LineClaims.fromJson(Map<String, dynamic>.from(value as Map)),
  };
}

Map<String, Object?> claimsToJson(Map<String, LineClaims> claims) =>
    {for (final MapEntry(:key, :value) in claims.entries) key: value.toJson()};

@freezed
abstract class Rules with _$Rules {
  const factory Rules({
    /// 'proportional' ("By what they had") or 'even'.
    @Default('proportional') String serviceMode,
    @Default(<String>[]) List<String> onUs,
    List<String>? onUsPaidBy,
    @Default(<String>[]) List<String> serviceOptOut,
  }) = _Rules;

  factory Rules.fromJson(Map<String, dynamic> json) => _$RulesFromJson(json);
}

@freezed
abstract class BreakdownLine with _$BreakdownLine {
  const factory BreakdownLine({
    required String lineId,
    required int minor,

    /// '' for a whole line, '2 of 3', or 'share'.
    @Default('') String portionLabel,
  }) = _BreakdownLine;

  factory BreakdownLine.fromJson(Map<String, dynamic> json) => _$BreakdownLineFromJson(json);
}

/// One person's share, as allocate() worked it out. Display only: the app
/// never recomputes any of these.
@freezed
abstract class Breakdown with _$Breakdown {
  const factory Breakdown({
    @Default(0) int itemsMinor,

    /// Negative for the person who is on us: their items moved to others.
    @Default(0) int sharedFromOnUsMinor,
    @Default(0) int serviceMinor,
    @Default(0) int tipMinor,
    @Default(0) int discountMinor,
    @Default(0) int finalMinor,
    @Default(<BreakdownLine>[]) List<BreakdownLine> lines,
  }) = _Breakdown;

  factory Breakdown.fromJson(Map<String, dynamic> json) => _$BreakdownFromJson(json);
}

/// The API's `Allocation` union in one shape: `ok` with shares, or not ok
/// with the problems in the way.
@freezed
abstract class Computed with _$Computed {
  const factory Computed({
    @Default(false) bool ok,
    @Default(<String, Breakdown>{}) Map<String, Breakdown> perParticipant,
    int? totalMinor,
    @Default(<Ambiguity>[]) List<Ambiguity> problems,
  }) = _Computed;

  factory Computed.fromJson(Map<String, dynamic> json) => _$ComputedFromJson(json);
}

/// organisers/{uid}/splits/{splitId}. Spec §2.
@freezed
abstract class SplitDoc with _$SplitDoc {
  const SplitDoc._();

  const factory SplitDoc({
    required String id,
    @Default('Your bill') String title,
    String? merchant,

    /// ISO date, e.g. 2026-10-02.
    String? receiptDate,

    /// draft, claiming, collecting, settled or cancelled.
    @Default('draft') String status,
    @Default(Receipt()) Receipt receipt,
    @Default(<Ambiguity>[]) List<Ambiguity> receiptAmbiguities,
    @JsonKey(fromJson: claimsFromJson, toJson: claimsToJson)
    @Default(<String, LineClaims>{})
    Map<String, LineClaims> claims,
    @Default(Rules()) Rules rules,
    @Default('') String organiserParticipantId,
    Computed? computed,

    /// Each friend's share link by participant id, written by *open*. The
    /// Tracker's *Copy link* and *Preview* read it.
    @Default(<String, String>{}) Map<String, String> links,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? createdAt,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? updatedAt,
  }) = _SplitDoc;

  factory SplitDoc.fromJson(Map<String, dynamic> json) => _$SplitDocFromJson(json);

  /// What stops the organiser going on. Derived by the API from the numbers.
  List<Ambiguity> get blocking => [for (final a in receiptAmbiguities) if (a.blocking) a];

  /// The model's own questions, shown but never in the way.
  List<Ambiguity> get notes => [for (final a in receiptAmbiguities) if (!a.blocking) a];

  bool get isDraft => status == 'draft';
  bool get isOpen => status != 'settled' && status != 'cancelled';
}
