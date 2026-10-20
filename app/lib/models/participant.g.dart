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
    };
