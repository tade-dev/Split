// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Claim _$ClaimFromJson(Map<String, dynamic> json) => _Claim(
  participantId: json['participantId'] as String,
  weight: (json['weight'] as num?)?.toInt() ?? 1,
  source: json['source'] as String? ?? 'organiser',
);

Map<String, dynamic> _$ClaimToJson(_Claim instance) => <String, dynamic>{
  'participantId': instance.participantId,
  'weight': instance.weight,
  'source': instance.source,
};

_LineClaims _$LineClaimsFromJson(Map<String, dynamic> json) => _LineClaims(
  claims:
      (json['claims'] as List<dynamic>?)
          ?.map((e) => Claim.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Claim>[],
  shared: json['shared'] as bool? ?? false,
);

Map<String, dynamic> _$LineClaimsToJson(_LineClaims instance) =>
    <String, dynamic>{
      'claims': instance.claims.map((e) => e.toJson()).toList(),
      'shared': instance.shared,
    };

_Rules _$RulesFromJson(Map<String, dynamic> json) => _Rules(
  serviceMode: json['serviceMode'] as String? ?? 'proportional',
  onUs:
      (json['onUs'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  onUsPaidBy: (json['onUsPaidBy'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  serviceOptOut:
      (json['serviceOptOut'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$RulesToJson(_Rules instance) => <String, dynamic>{
  'serviceMode': instance.serviceMode,
  'onUs': instance.onUs,
  'onUsPaidBy': instance.onUsPaidBy,
  'serviceOptOut': instance.serviceOptOut,
};

_BreakdownLine _$BreakdownLineFromJson(Map<String, dynamic> json) =>
    _BreakdownLine(
      lineId: json['lineId'] as String,
      minor: (json['minor'] as num).toInt(),
      portionLabel: json['portionLabel'] as String? ?? '',
    );

Map<String, dynamic> _$BreakdownLineToJson(_BreakdownLine instance) =>
    <String, dynamic>{
      'lineId': instance.lineId,
      'minor': instance.minor,
      'portionLabel': instance.portionLabel,
    };

_Breakdown _$BreakdownFromJson(Map<String, dynamic> json) => _Breakdown(
  itemsMinor: (json['itemsMinor'] as num?)?.toInt() ?? 0,
  sharedFromOnUsMinor: (json['sharedFromOnUsMinor'] as num?)?.toInt() ?? 0,
  serviceMinor: (json['serviceMinor'] as num?)?.toInt() ?? 0,
  tipMinor: (json['tipMinor'] as num?)?.toInt() ?? 0,
  discountMinor: (json['discountMinor'] as num?)?.toInt() ?? 0,
  finalMinor: (json['finalMinor'] as num?)?.toInt() ?? 0,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => BreakdownLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <BreakdownLine>[],
);

Map<String, dynamic> _$BreakdownToJson(_Breakdown instance) =>
    <String, dynamic>{
      'itemsMinor': instance.itemsMinor,
      'sharedFromOnUsMinor': instance.sharedFromOnUsMinor,
      'serviceMinor': instance.serviceMinor,
      'tipMinor': instance.tipMinor,
      'discountMinor': instance.discountMinor,
      'finalMinor': instance.finalMinor,
      'lines': instance.lines.map((e) => e.toJson()).toList(),
    };

_Computed _$ComputedFromJson(Map<String, dynamic> json) => _Computed(
  ok: json['ok'] as bool? ?? false,
  perParticipant:
      (json['perParticipant'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, Breakdown.fromJson(e as Map<String, dynamic>)),
      ) ??
      const <String, Breakdown>{},
  totalMinor: (json['totalMinor'] as num?)?.toInt(),
  problems:
      (json['problems'] as List<dynamic>?)
          ?.map((e) => Ambiguity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ambiguity>[],
);

Map<String, dynamic> _$ComputedToJson(_Computed instance) => <String, dynamic>{
  'ok': instance.ok,
  'perParticipant': instance.perParticipant.map(
    (k, e) => MapEntry(k, e.toJson()),
  ),
  'totalMinor': instance.totalMinor,
  'problems': instance.problems.map((e) => e.toJson()).toList(),
};

_SplitDoc _$SplitDocFromJson(Map<String, dynamic> json) => _SplitDoc(
  id: json['id'] as String,
  title: json['title'] as String? ?? 'Your bill',
  merchant: json['merchant'] as String?,
  receiptDate: json['receiptDate'] as String?,
  status: json['status'] as String? ?? 'draft',
  receipt: json['receipt'] == null
      ? const Receipt()
      : Receipt.fromJson(json['receipt'] as Map<String, dynamic>),
  receiptAmbiguities:
      (json['receiptAmbiguities'] as List<dynamic>?)
          ?.map((e) => Ambiguity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ambiguity>[],
  claims: json['claims'] == null
      ? const <String, LineClaims>{}
      : claimsFromJson(json['claims']),
  rules: json['rules'] == null
      ? const Rules()
      : Rules.fromJson(json['rules'] as Map<String, dynamic>),
  organiserParticipantId: json['organiserParticipantId'] as String? ?? '',
  computed: json['computed'] == null
      ? null
      : Computed.fromJson(json['computed'] as Map<String, dynamic>),
  links:
      (json['links'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  createdAt: dateTimeFromJson(json['createdAt']),
  updatedAt: dateTimeFromJson(json['updatedAt']),
);

Map<String, dynamic> _$SplitDocToJson(_SplitDoc instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'merchant': instance.merchant,
  'receiptDate': instance.receiptDate,
  'status': instance.status,
  'receipt': instance.receipt.toJson(),
  'receiptAmbiguities': instance.receiptAmbiguities
      .map((e) => e.toJson())
      .toList(),
  'claims': claimsToJson(instance.claims),
  'rules': instance.rules.toJson(),
  'organiserParticipantId': instance.organiserParticipantId,
  'computed': instance.computed?.toJson(),
  'links': instance.links,
  'createdAt': dateTimeToJson(instance.createdAt),
  'updatedAt': dateTimeToJson(instance.updatedAt),
};
