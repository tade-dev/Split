// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'participant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Participant {

 String get id; String get name; int get colourIndex; bool get isOrganiser; int get joinOrder; String get status; int? get shareMinor;/// What they typed on their link, verbatim. Null when they picked from
/// the bill instead, or the organiser claimed for them.
 String? get claimText;@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get claimedAt;
/// Create a copy of Participant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParticipantCopyWith<Participant> get copyWith => _$ParticipantCopyWithImpl<Participant>(this as Participant, _$identity);

  /// Serializes this Participant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Participant;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Participant&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.colourIndex, _this.colourIndex) || other.colourIndex == _this.colourIndex)&&(identical(other.isOrganiser, _this.isOrganiser) || other.isOrganiser == _this.isOrganiser)&&(identical(other.joinOrder, _this.joinOrder) || other.joinOrder == _this.joinOrder)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.shareMinor, _this.shareMinor) || other.shareMinor == _this.shareMinor)&&(identical(other.claimText, _this.claimText) || other.claimText == _this.claimText)&&(identical(other.claimedAt, _this.claimedAt) || other.claimedAt == _this.claimedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Participant;
  return Object.hash(runtimeType,_this.id,_this.name,_this.colourIndex,_this.isOrganiser,_this.joinOrder,_this.status,_this.shareMinor,_this.claimText,_this.claimedAt);
}

@override
String toString() {
  final _this = this as Participant;
  return 'Participant(id: ${_this.id}, name: ${_this.name}, colourIndex: ${_this.colourIndex}, isOrganiser: ${_this.isOrganiser}, joinOrder: ${_this.joinOrder}, status: ${_this.status}, shareMinor: ${_this.shareMinor}, claimText: ${_this.claimText}, claimedAt: ${_this.claimedAt})';
}


}

/// @nodoc
abstract mixin class $ParticipantCopyWith<$Res>  {
  factory $ParticipantCopyWith(Participant value, $Res Function(Participant) _then) = _$ParticipantCopyWithImpl;
@useResult
$Res call({
 String id, String name, int colourIndex, bool isOrganiser, int joinOrder, String status, int? shareMinor, String? claimText,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? claimedAt
});




}
/// @nodoc
class _$ParticipantCopyWithImpl<$Res>
    implements $ParticipantCopyWith<$Res> {
  _$ParticipantCopyWithImpl(this._self, this._then);

  final Participant _self;
  final $Res Function(Participant) _then;

/// Create a copy of Participant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? colourIndex = null,Object? isOrganiser = null,Object? joinOrder = null,Object? status = null,Object? shareMinor = freezed,Object? claimText = freezed,Object? claimedAt = freezed,}) {
  return _then(Participant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colourIndex: null == colourIndex ? _self.colourIndex : colourIndex // ignore: cast_nullable_to_non_nullable
as int,isOrganiser: null == isOrganiser ? _self.isOrganiser : isOrganiser // ignore: cast_nullable_to_non_nullable
as bool,joinOrder: null == joinOrder ? _self.joinOrder : joinOrder // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,shareMinor: freezed == shareMinor ? _self.shareMinor : shareMinor // ignore: cast_nullable_to_non_nullable
as int?,claimText: freezed == claimText ? _self.claimText : claimText // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Participant].
extension ParticipantPatterns on Participant {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Participant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Participant() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Participant value)  $default,){
final _that = this;
switch (_that) {
case _Participant():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Participant value)?  $default,){
final _that = this;
switch (_that) {
case _Participant() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int colourIndex,  bool isOrganiser,  int joinOrder,  String status,  int? shareMinor,  String? claimText, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? claimedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Participant() when $default != null:
return $default(_that.id,_that.name,_that.colourIndex,_that.isOrganiser,_that.joinOrder,_that.status,_that.shareMinor,_that.claimText,_that.claimedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int colourIndex,  bool isOrganiser,  int joinOrder,  String status,  int? shareMinor,  String? claimText, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? claimedAt)  $default,) {final _that = this;
switch (_that) {
case _Participant():
return $default(_that.id,_that.name,_that.colourIndex,_that.isOrganiser,_that.joinOrder,_that.status,_that.shareMinor,_that.claimText,_that.claimedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int colourIndex,  bool isOrganiser,  int joinOrder,  String status,  int? shareMinor,  String? claimText, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? claimedAt)?  $default,) {final _that = this;
switch (_that) {
case _Participant() when $default != null:
return $default(_that.id,_that.name,_that.colourIndex,_that.isOrganiser,_that.joinOrder,_that.status,_that.shareMinor,_that.claimText,_that.claimedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Participant implements Participant {
  const _Participant({required this.id, required this.name, this.colourIndex = 0, this.isOrganiser = false, this.joinOrder = 0, this.status = 'invited', this.shareMinor, this.claimText, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.claimedAt});
  factory _Participant.fromJson(Map<String, dynamic> json) => _$ParticipantFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int colourIndex;
@override@JsonKey() final  bool isOrganiser;
@override@JsonKey() final  int joinOrder;
@override@JsonKey() final  String status;
@override final  int? shareMinor;
/// What they typed on their link, verbatim. Null when they picked from
/// the bill instead, or the organiser claimed for them.
@override final  String? claimText;
@override@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? claimedAt;

/// Create a copy of Participant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParticipantCopyWith<_Participant> get copyWith => __$ParticipantCopyWithImpl<_Participant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParticipantToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Participant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.colourIndex, colourIndex) || other.colourIndex == colourIndex)&&(identical(other.isOrganiser, isOrganiser) || other.isOrganiser == isOrganiser)&&(identical(other.joinOrder, joinOrder) || other.joinOrder == joinOrder)&&(identical(other.status, status) || other.status == status)&&(identical(other.shareMinor, shareMinor) || other.shareMinor == shareMinor)&&(identical(other.claimText, claimText) || other.claimText == claimText)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,colourIndex,isOrganiser,joinOrder,status,shareMinor,claimText,claimedAt);
}

@override
String toString() {
    return 'Participant(id: $id, name: $name, colourIndex: $colourIndex, isOrganiser: $isOrganiser, joinOrder: $joinOrder, status: $status, shareMinor: $shareMinor, claimText: $claimText, claimedAt: $claimedAt)';
}


}

/// @nodoc
abstract mixin class _$ParticipantCopyWith<$Res> implements $ParticipantCopyWith<$Res> {
  factory _$ParticipantCopyWith(_Participant value, $Res Function(_Participant) _then) = __$ParticipantCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int colourIndex, bool isOrganiser, int joinOrder, String status, int? shareMinor, String? claimText,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? claimedAt
});




}
/// @nodoc
class __$ParticipantCopyWithImpl<$Res>
    implements _$ParticipantCopyWith<$Res> {
  __$ParticipantCopyWithImpl(this._self, this._then);

  final _Participant _self;
  final $Res Function(_Participant) _then;

/// Create a copy of Participant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? colourIndex = null,Object? isOrganiser = null,Object? joinOrder = null,Object? status = null,Object? shareMinor = freezed,Object? claimText = freezed,Object? claimedAt = freezed,}) {
  return _then(_Participant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colourIndex: null == colourIndex ? _self.colourIndex : colourIndex // ignore: cast_nullable_to_non_nullable
as int,isOrganiser: null == isOrganiser ? _self.isOrganiser : isOrganiser // ignore: cast_nullable_to_non_nullable
as bool,joinOrder: null == joinOrder ? _self.joinOrder : joinOrder // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,shareMinor: freezed == shareMinor ? _self.shareMinor : shareMinor // ignore: cast_nullable_to_non_nullable
as int?,claimText: freezed == claimText ? _self.claimText : claimText // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
