// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organiser.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Organiser {

 String get id;/// The name friends see: "Kemi".
 String get displayName;/// Where friends' payments go. Null pays the shared sandbox merchant.
 String? get paypalEmail;
/// Create a copy of Organiser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganiserCopyWith<Organiser> get copyWith => _$OrganiserCopyWithImpl<Organiser>(this as Organiser, _$identity);

  /// Serializes this Organiser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Organiser;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Organiser&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.paypalEmail, _this.paypalEmail) || other.paypalEmail == _this.paypalEmail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Organiser;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.paypalEmail);
}

@override
String toString() {
  final _this = this as Organiser;
  return 'Organiser(id: ${_this.id}, displayName: ${_this.displayName}, paypalEmail: ${_this.paypalEmail})';
}


}

/// @nodoc
abstract mixin class $OrganiserCopyWith<$Res>  {
  factory $OrganiserCopyWith(Organiser value, $Res Function(Organiser) _then) = _$OrganiserCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? paypalEmail
});




}
/// @nodoc
class _$OrganiserCopyWithImpl<$Res>
    implements $OrganiserCopyWith<$Res> {
  _$OrganiserCopyWithImpl(this._self, this._then);

  final Organiser _self;
  final $Res Function(Organiser) _then;

/// Create a copy of Organiser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? paypalEmail = freezed,}) {
  return _then(Organiser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,paypalEmail: freezed == paypalEmail ? _self.paypalEmail : paypalEmail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Organiser].
extension OrganiserPatterns on Organiser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Organiser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Organiser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Organiser value)  $default,){
final _that = this;
switch (_that) {
case _Organiser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Organiser value)?  $default,){
final _that = this;
switch (_that) {
case _Organiser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? paypalEmail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Organiser() when $default != null:
return $default(_that.id,_that.displayName,_that.paypalEmail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? paypalEmail)  $default,) {final _that = this;
switch (_that) {
case _Organiser():
return $default(_that.id,_that.displayName,_that.paypalEmail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? paypalEmail)?  $default,) {final _that = this;
switch (_that) {
case _Organiser() when $default != null:
return $default(_that.id,_that.displayName,_that.paypalEmail);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Organiser implements Organiser {
  const _Organiser({required this.id, this.displayName = '', this.paypalEmail});
  factory _Organiser.fromJson(Map<String, dynamic> json) => _$OrganiserFromJson(json);

@override final  String id;
/// The name friends see: "Kemi".
@override@JsonKey() final  String displayName;
/// Where friends' payments go. Null pays the shared sandbox merchant.
@override final  String? paypalEmail;

/// Create a copy of Organiser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganiserCopyWith<_Organiser> get copyWith => __$OrganiserCopyWithImpl<_Organiser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganiserToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Organiser&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.paypalEmail, paypalEmail) || other.paypalEmail == paypalEmail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,paypalEmail);
}

@override
String toString() {
    return 'Organiser(id: $id, displayName: $displayName, paypalEmail: $paypalEmail)';
}


}

/// @nodoc
abstract mixin class _$OrganiserCopyWith<$Res> implements $OrganiserCopyWith<$Res> {
  factory _$OrganiserCopyWith(_Organiser value, $Res Function(_Organiser) _then) = __$OrganiserCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? paypalEmail
});




}
/// @nodoc
class __$OrganiserCopyWithImpl<$Res>
    implements _$OrganiserCopyWith<$Res> {
  __$OrganiserCopyWithImpl(this._self, this._then);

  final _Organiser _self;
  final $Res Function(_Organiser) _then;

/// Create a copy of Organiser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? paypalEmail = freezed,}) {
  return _then(_Organiser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,paypalEmail: freezed == paypalEmail ? _self.paypalEmail : paypalEmail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
