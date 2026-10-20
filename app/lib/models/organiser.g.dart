// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organiser.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Organiser _$OrganiserFromJson(Map<String, dynamic> json) => _Organiser(
  id: json['id'] as String,
  displayName: json['displayName'] as String? ?? '',
  paypalEmail: json['paypalEmail'] as String?,
);

Map<String, dynamic> _$OrganiserToJson(_Organiser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'paypalEmail': instance.paypalEmail,
    };
