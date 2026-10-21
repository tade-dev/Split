// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Participant _$ParticipantFromJson(Map<String, dynamic> json) => _Participant(
  id: json['id'] as String,
  name: json['name'] as String,
  colourIndex: (json['colourIndex'] as num?)?.toInt() ?? 0,
  isOrganiser: json['isOrganiser'] as bool? ?? false,
  joinOrder: (json['joinOrder'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? 'invited',
  shareMinor: (json['shareMinor'] as num?)?.toInt(),
  claimText: json['claimText'] as String?,
  claimedAt: dateTimeFromJson(json['claimedAt']),
  linkOpenedAt: dateTimeFromJson(json['linkOpenedAt']),
  paidAt: dateTimeFromJson(json['paidAt']),
);

Map<String, dynamic> _$ParticipantToJson(_Participant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'colourIndex': instance.colourIndex,
      'isOrganiser': instance.isOrganiser,
      'joinOrder': instance.joinOrder,
      'status': instance.status,
      'shareMinor': instance.shareMinor,
      'claimText': instance.claimText,
      'claimedAt': dateTimeToJson(instance.claimedAt),
      'linkOpenedAt': dateTimeToJson(instance.linkOpenedAt),
      'paidAt': dateTimeToJson(instance.paidAt),
    };
