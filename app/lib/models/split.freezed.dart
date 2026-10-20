// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'split.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Claim {

 String get participantId; int get weight; String get source;
/// Create a copy of Claim
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaimCopyWith<Claim> get copyWith => _$ClaimCopyWithImpl<Claim>(this as Claim, _$identity);

  /// Serializes this Claim to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Claim;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Claim&&(identical(other.participantId, _this.participantId) || other.participantId == _this.participantId)&&(identical(other.weight, _this.weight) || other.weight == _this.weight)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Claim;
  return Object.hash(runtimeType,_this.participantId,_this.weight,_this.source);
}

@override
String toString() {
  final _this = this as Claim;
  return 'Claim(participantId: ${_this.participantId}, weight: ${_this.weight}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $ClaimCopyWith<$Res>  {
  factory $ClaimCopyWith(Claim value, $Res Function(Claim) _then) = _$ClaimCopyWithImpl;
@useResult
$Res call({
 String participantId, int weight, String source
});




}
/// @nodoc
class _$ClaimCopyWithImpl<$Res>
    implements $ClaimCopyWith<$Res> {
  _$ClaimCopyWithImpl(this._self, this._then);

  final Claim _self;
  final $Res Function(Claim) _then;

/// Create a copy of Claim
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? participantId = null,Object? weight = null,Object? source = null,}) {
  return _then(Claim(
participantId: null == participantId ? _self.participantId : participantId // ignore: cast_nullable_to_non_nullable
as String,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Claim].
extension ClaimPatterns on Claim {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Claim value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Claim() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Claim value)  $default,){
final _that = this;
switch (_that) {
case _Claim():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Claim value)?  $default,){
final _that = this;
switch (_that) {
case _Claim() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String participantId,  int weight,  String source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Claim() when $default != null:
return $default(_that.participantId,_that.weight,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String participantId,  int weight,  String source)  $default,) {final _that = this;
switch (_that) {
case _Claim():
return $default(_that.participantId,_that.weight,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String participantId,  int weight,  String source)?  $default,) {final _that = this;
switch (_that) {
case _Claim() when $default != null:
return $default(_that.participantId,_that.weight,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Claim implements Claim {
  const _Claim({required this.participantId, this.weight = 1, this.source = 'organiser'});
  factory _Claim.fromJson(Map<String, dynamic> json) => _$ClaimFromJson(json);

@override final  String participantId;
@override@JsonKey() final  int weight;
@override@JsonKey() final  String source;

/// Create a copy of Claim
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaimCopyWith<_Claim> get copyWith => __$ClaimCopyWithImpl<_Claim>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaimToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Claim&&(identical(other.participantId, participantId) || other.participantId == participantId)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,participantId,weight,source);
}

@override
String toString() {
    return 'Claim(participantId: $participantId, weight: $weight, source: $source)';
}


}

/// @nodoc
abstract mixin class _$ClaimCopyWith<$Res> implements $ClaimCopyWith<$Res> {
  factory _$ClaimCopyWith(_Claim value, $Res Function(_Claim) _then) = __$ClaimCopyWithImpl;
@override @useResult
$Res call({
 String participantId, int weight, String source
});




}
/// @nodoc
class __$ClaimCopyWithImpl<$Res>
    implements _$ClaimCopyWith<$Res> {
  __$ClaimCopyWithImpl(this._self, this._then);

  final _Claim _self;
  final $Res Function(_Claim) _then;

/// Create a copy of Claim
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? participantId = null,Object? weight = null,Object? source = null,}) {
  return _then(_Claim(
participantId: null == participantId ? _self.participantId : participantId // ignore: cast_nullable_to_non_nullable
as String,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Rules {

/// 'proportional' ("By what they had") or 'even'.
 String get serviceMode; List<String> get onUs; List<String>? get onUsPaidBy; List<String> get serviceOptOut;
/// Create a copy of Rules
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RulesCopyWith<Rules> get copyWith => _$RulesCopyWithImpl<Rules>(this as Rules, _$identity);

  /// Serializes this Rules to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Rules;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Rules&&(identical(other.serviceMode, _this.serviceMode) || other.serviceMode == _this.serviceMode)&&const DeepCollectionEquality().equals(other.onUs, _this.onUs)&&const DeepCollectionEquality().equals(other.onUsPaidBy, _this.onUsPaidBy)&&const DeepCollectionEquality().equals(other.serviceOptOut, _this.serviceOptOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Rules;
  return Object.hash(runtimeType,_this.serviceMode,const DeepCollectionEquality().hash(_this.onUs),const DeepCollectionEquality().hash(_this.onUsPaidBy),const DeepCollectionEquality().hash(_this.serviceOptOut));
}

@override
String toString() {
  final _this = this as Rules;
  return 'Rules(serviceMode: ${_this.serviceMode}, onUs: ${_this.onUs}, onUsPaidBy: ${_this.onUsPaidBy}, serviceOptOut: ${_this.serviceOptOut})';
}


}

/// @nodoc
abstract mixin class $RulesCopyWith<$Res>  {
  factory $RulesCopyWith(Rules value, $Res Function(Rules) _then) = _$RulesCopyWithImpl;
@useResult
$Res call({
 String serviceMode, List<String> onUs, List<String>? onUsPaidBy, List<String> serviceOptOut
});




}
/// @nodoc
class _$RulesCopyWithImpl<$Res>
    implements $RulesCopyWith<$Res> {
  _$RulesCopyWithImpl(this._self, this._then);

  final Rules _self;
  final $Res Function(Rules) _then;

/// Create a copy of Rules
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceMode = null,Object? onUs = null,Object? onUsPaidBy = freezed,Object? serviceOptOut = null,}) {
  return _then(Rules(
serviceMode: null == serviceMode ? _self.serviceMode : serviceMode // ignore: cast_nullable_to_non_nullable
as String,onUs: null == onUs ? _self.onUs : onUs // ignore: cast_nullable_to_non_nullable
as List<String>,onUsPaidBy: freezed == onUsPaidBy ? _self.onUsPaidBy : onUsPaidBy // ignore: cast_nullable_to_non_nullable
as List<String>?,serviceOptOut: null == serviceOptOut ? _self.serviceOptOut : serviceOptOut // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Rules].
extension RulesPatterns on Rules {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Rules value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Rules() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Rules value)  $default,){
final _that = this;
switch (_that) {
case _Rules():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Rules value)?  $default,){
final _that = this;
switch (_that) {
case _Rules() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serviceMode,  List<String> onUs,  List<String>? onUsPaidBy,  List<String> serviceOptOut)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Rules() when $default != null:
return $default(_that.serviceMode,_that.onUs,_that.onUsPaidBy,_that.serviceOptOut);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serviceMode,  List<String> onUs,  List<String>? onUsPaidBy,  List<String> serviceOptOut)  $default,) {final _that = this;
switch (_that) {
case _Rules():
return $default(_that.serviceMode,_that.onUs,_that.onUsPaidBy,_that.serviceOptOut);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serviceMode,  List<String> onUs,  List<String>? onUsPaidBy,  List<String> serviceOptOut)?  $default,) {final _that = this;
switch (_that) {
case _Rules() when $default != null:
return $default(_that.serviceMode,_that.onUs,_that.onUsPaidBy,_that.serviceOptOut);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Rules implements Rules {
  const _Rules({this.serviceMode = 'proportional',  List<String> onUs = const <String>[],  List<String>? onUsPaidBy,  List<String> serviceOptOut = const <String>[]}): _onUs = onUs,_onUsPaidBy = onUsPaidBy,_serviceOptOut = serviceOptOut;
  factory _Rules.fromJson(Map<String, dynamic> json) => _$RulesFromJson(json);

/// 'proportional' ("By what they had") or 'even'.
@override@JsonKey() final  String serviceMode;
 final  List<String> _onUs;
@override@JsonKey() List<String> get onUs {
  if (_onUs is EqualUnmodifiableListView) return _onUs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_onUs);
}

 final  List<String>? _onUsPaidBy;
@override List<String>? get onUsPaidBy {
  final value = _onUsPaidBy;
  if (value == null) return null;
  if (_onUsPaidBy is EqualUnmodifiableListView) return _onUsPaidBy;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String> _serviceOptOut;
@override@JsonKey() List<String> get serviceOptOut {
  if (_serviceOptOut is EqualUnmodifiableListView) return _serviceOptOut;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serviceOptOut);
}


/// Create a copy of Rules
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RulesCopyWith<_Rules> get copyWith => __$RulesCopyWithImpl<_Rules>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RulesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Rules&&(identical(other.serviceMode, serviceMode) || other.serviceMode == serviceMode)&&const DeepCollectionEquality().equals(other.onUs, _onUs)&&const DeepCollectionEquality().equals(other.onUsPaidBy, _onUsPaidBy)&&const DeepCollectionEquality().equals(other.serviceOptOut, _serviceOptOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,serviceMode,const DeepCollectionEquality().hash(_onUs),const DeepCollectionEquality().hash(_onUsPaidBy),const DeepCollectionEquality().hash(_serviceOptOut));
}

@override
String toString() {
    return 'Rules(serviceMode: $serviceMode, onUs: $onUs, onUsPaidBy: $onUsPaidBy, serviceOptOut: $serviceOptOut)';
}


}

/// @nodoc
abstract mixin class _$RulesCopyWith<$Res> implements $RulesCopyWith<$Res> {
  factory _$RulesCopyWith(_Rules value, $Res Function(_Rules) _then) = __$RulesCopyWithImpl;
@override @useResult
$Res call({
 String serviceMode, List<String> onUs, List<String>? onUsPaidBy, List<String> serviceOptOut
});




}
/// @nodoc
class __$RulesCopyWithImpl<$Res>
    implements _$RulesCopyWith<$Res> {
  __$RulesCopyWithImpl(this._self, this._then);

  final _Rules _self;
  final $Res Function(_Rules) _then;

/// Create a copy of Rules
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceMode = null,Object? onUs = null,Object? onUsPaidBy = freezed,Object? serviceOptOut = null,}) {
  return _then(_Rules(
serviceMode: null == serviceMode ? _self.serviceMode : serviceMode // ignore: cast_nullable_to_non_nullable
as String,onUs: null == onUs ? _self._onUs : onUs // ignore: cast_nullable_to_non_nullable
as List<String>,onUsPaidBy: freezed == onUsPaidBy ? _self._onUsPaidBy : onUsPaidBy // ignore: cast_nullable_to_non_nullable
as List<String>?,serviceOptOut: null == serviceOptOut ? _self._serviceOptOut : serviceOptOut // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$BreakdownLine {

 String get lineId; int get minor;/// '' for a whole line, '2 of 3', or 'share'.
 String get portionLabel;
/// Create a copy of BreakdownLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreakdownLineCopyWith<BreakdownLine> get copyWith => _$BreakdownLineCopyWithImpl<BreakdownLine>(this as BreakdownLine, _$identity);

  /// Serializes this BreakdownLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BreakdownLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BreakdownLine&&(identical(other.lineId, _this.lineId) || other.lineId == _this.lineId)&&(identical(other.minor, _this.minor) || other.minor == _this.minor)&&(identical(other.portionLabel, _this.portionLabel) || other.portionLabel == _this.portionLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BreakdownLine;
  return Object.hash(runtimeType,_this.lineId,_this.minor,_this.portionLabel);
}

@override
String toString() {
  final _this = this as BreakdownLine;
  return 'BreakdownLine(lineId: ${_this.lineId}, minor: ${_this.minor}, portionLabel: ${_this.portionLabel})';
}


}

/// @nodoc
abstract mixin class $BreakdownLineCopyWith<$Res>  {
  factory $BreakdownLineCopyWith(BreakdownLine value, $Res Function(BreakdownLine) _then) = _$BreakdownLineCopyWithImpl;
@useResult
$Res call({
 String lineId, int minor, String portionLabel
});




}
/// @nodoc
class _$BreakdownLineCopyWithImpl<$Res>
    implements $BreakdownLineCopyWith<$Res> {
  _$BreakdownLineCopyWithImpl(this._self, this._then);

  final BreakdownLine _self;
  final $Res Function(BreakdownLine) _then;

/// Create a copy of BreakdownLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lineId = null,Object? minor = null,Object? portionLabel = null,}) {
  return _then(BreakdownLine(
lineId: null == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String,minor: null == minor ? _self.minor : minor // ignore: cast_nullable_to_non_nullable
as int,portionLabel: null == portionLabel ? _self.portionLabel : portionLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BreakdownLine].
extension BreakdownLinePatterns on BreakdownLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BreakdownLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BreakdownLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BreakdownLine value)  $default,){
final _that = this;
switch (_that) {
case _BreakdownLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BreakdownLine value)?  $default,){
final _that = this;
switch (_that) {
case _BreakdownLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String lineId,  int minor,  String portionLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BreakdownLine() when $default != null:
return $default(_that.lineId,_that.minor,_that.portionLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String lineId,  int minor,  String portionLabel)  $default,) {final _that = this;
switch (_that) {
case _BreakdownLine():
return $default(_that.lineId,_that.minor,_that.portionLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String lineId,  int minor,  String portionLabel)?  $default,) {final _that = this;
switch (_that) {
case _BreakdownLine() when $default != null:
return $default(_that.lineId,_that.minor,_that.portionLabel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BreakdownLine implements BreakdownLine {
  const _BreakdownLine({required this.lineId, required this.minor, this.portionLabel = ''});
  factory _BreakdownLine.fromJson(Map<String, dynamic> json) => _$BreakdownLineFromJson(json);

@override final  String lineId;
@override final  int minor;
/// '' for a whole line, '2 of 3', or 'share'.
@override@JsonKey() final  String portionLabel;

/// Create a copy of BreakdownLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BreakdownLineCopyWith<_BreakdownLine> get copyWith => __$BreakdownLineCopyWithImpl<_BreakdownLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BreakdownLineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BreakdownLine&&(identical(other.lineId, lineId) || other.lineId == lineId)&&(identical(other.minor, minor) || other.minor == minor)&&(identical(other.portionLabel, portionLabel) || other.portionLabel == portionLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,lineId,minor,portionLabel);
}

@override
String toString() {
    return 'BreakdownLine(lineId: $lineId, minor: $minor, portionLabel: $portionLabel)';
}


}

/// @nodoc
abstract mixin class _$BreakdownLineCopyWith<$Res> implements $BreakdownLineCopyWith<$Res> {
  factory _$BreakdownLineCopyWith(_BreakdownLine value, $Res Function(_BreakdownLine) _then) = __$BreakdownLineCopyWithImpl;
@override @useResult
$Res call({
 String lineId, int minor, String portionLabel
});




}
/// @nodoc
class __$BreakdownLineCopyWithImpl<$Res>
    implements _$BreakdownLineCopyWith<$Res> {
  __$BreakdownLineCopyWithImpl(this._self, this._then);

  final _BreakdownLine _self;
  final $Res Function(_BreakdownLine) _then;

/// Create a copy of BreakdownLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lineId = null,Object? minor = null,Object? portionLabel = null,}) {
  return _then(_BreakdownLine(
lineId: null == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String,minor: null == minor ? _self.minor : minor // ignore: cast_nullable_to_non_nullable
as int,portionLabel: null == portionLabel ? _self.portionLabel : portionLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Breakdown {

 int get itemsMinor;/// Negative for the person who is on us: their items moved to others.
 int get sharedFromOnUsMinor; int get serviceMinor; int get tipMinor; int get discountMinor; int get finalMinor; List<BreakdownLine> get lines;
/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreakdownCopyWith<Breakdown> get copyWith => _$BreakdownCopyWithImpl<Breakdown>(this as Breakdown, _$identity);

  /// Serializes this Breakdown to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Breakdown;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Breakdown&&(identical(other.itemsMinor, _this.itemsMinor) || other.itemsMinor == _this.itemsMinor)&&(identical(other.sharedFromOnUsMinor, _this.sharedFromOnUsMinor) || other.sharedFromOnUsMinor == _this.sharedFromOnUsMinor)&&(identical(other.serviceMinor, _this.serviceMinor) || other.serviceMinor == _this.serviceMinor)&&(identical(other.tipMinor, _this.tipMinor) || other.tipMinor == _this.tipMinor)&&(identical(other.discountMinor, _this.discountMinor) || other.discountMinor == _this.discountMinor)&&(identical(other.finalMinor, _this.finalMinor) || other.finalMinor == _this.finalMinor)&&const DeepCollectionEquality().equals(other.lines, _this.lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Breakdown;
  return Object.hash(runtimeType,_this.itemsMinor,_this.sharedFromOnUsMinor,_this.serviceMinor,_this.tipMinor,_this.discountMinor,_this.finalMinor,const DeepCollectionEquality().hash(_this.lines));
}

@override
String toString() {
  final _this = this as Breakdown;
  return 'Breakdown(itemsMinor: ${_this.itemsMinor}, sharedFromOnUsMinor: ${_this.sharedFromOnUsMinor}, serviceMinor: ${_this.serviceMinor}, tipMinor: ${_this.tipMinor}, discountMinor: ${_this.discountMinor}, finalMinor: ${_this.finalMinor}, lines: ${_this.lines})';
}


}

/// @nodoc
abstract mixin class $BreakdownCopyWith<$Res>  {
  factory $BreakdownCopyWith(Breakdown value, $Res Function(Breakdown) _then) = _$BreakdownCopyWithImpl;
@useResult
$Res call({
 int itemsMinor, int sharedFromOnUsMinor, int serviceMinor, int tipMinor, int discountMinor, int finalMinor, List<BreakdownLine> lines
});




}
/// @nodoc
class _$BreakdownCopyWithImpl<$Res>
    implements $BreakdownCopyWith<$Res> {
  _$BreakdownCopyWithImpl(this._self, this._then);

  final Breakdown _self;
  final $Res Function(Breakdown) _then;

/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? itemsMinor = null,Object? sharedFromOnUsMinor = null,Object? serviceMinor = null,Object? tipMinor = null,Object? discountMinor = null,Object? finalMinor = null,Object? lines = null,}) {
  return _then(Breakdown(
itemsMinor: null == itemsMinor ? _self.itemsMinor : itemsMinor // ignore: cast_nullable_to_non_nullable
as int,sharedFromOnUsMinor: null == sharedFromOnUsMinor ? _self.sharedFromOnUsMinor : sharedFromOnUsMinor // ignore: cast_nullable_to_non_nullable
as int,serviceMinor: null == serviceMinor ? _self.serviceMinor : serviceMinor // ignore: cast_nullable_to_non_nullable
as int,tipMinor: null == tipMinor ? _self.tipMinor : tipMinor // ignore: cast_nullable_to_non_nullable
as int,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,finalMinor: null == finalMinor ? _self.finalMinor : finalMinor // ignore: cast_nullable_to_non_nullable
as int,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<BreakdownLine>,
  ));
}

}


/// Adds pattern-matching-related methods to [Breakdown].
extension BreakdownPatterns on Breakdown {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Breakdown value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Breakdown value)  $default,){
final _that = this;
switch (_that) {
case _Breakdown():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Breakdown value)?  $default,){
final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int itemsMinor,  int sharedFromOnUsMinor,  int serviceMinor,  int tipMinor,  int discountMinor,  int finalMinor,  List<BreakdownLine> lines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
return $default(_that.itemsMinor,_that.sharedFromOnUsMinor,_that.serviceMinor,_that.tipMinor,_that.discountMinor,_that.finalMinor,_that.lines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int itemsMinor,  int sharedFromOnUsMinor,  int serviceMinor,  int tipMinor,  int discountMinor,  int finalMinor,  List<BreakdownLine> lines)  $default,) {final _that = this;
switch (_that) {
case _Breakdown():
return $default(_that.itemsMinor,_that.sharedFromOnUsMinor,_that.serviceMinor,_that.tipMinor,_that.discountMinor,_that.finalMinor,_that.lines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int itemsMinor,  int sharedFromOnUsMinor,  int serviceMinor,  int tipMinor,  int discountMinor,  int finalMinor,  List<BreakdownLine> lines)?  $default,) {final _that = this;
switch (_that) {
case _Breakdown() when $default != null:
return $default(_that.itemsMinor,_that.sharedFromOnUsMinor,_that.serviceMinor,_that.tipMinor,_that.discountMinor,_that.finalMinor,_that.lines);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Breakdown implements Breakdown {
  const _Breakdown({this.itemsMinor = 0, this.sharedFromOnUsMinor = 0, this.serviceMinor = 0, this.tipMinor = 0, this.discountMinor = 0, this.finalMinor = 0,  List<BreakdownLine> lines = const <BreakdownLine>[]}): _lines = lines;
  factory _Breakdown.fromJson(Map<String, dynamic> json) => _$BreakdownFromJson(json);

@override@JsonKey() final  int itemsMinor;
/// Negative for the person who is on us: their items moved to others.
@override@JsonKey() final  int sharedFromOnUsMinor;
@override@JsonKey() final  int serviceMinor;
@override@JsonKey() final  int tipMinor;
@override@JsonKey() final  int discountMinor;
@override@JsonKey() final  int finalMinor;
 final  List<BreakdownLine> _lines;
@override@JsonKey() List<BreakdownLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BreakdownCopyWith<_Breakdown> get copyWith => __$BreakdownCopyWithImpl<_Breakdown>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BreakdownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Breakdown&&(identical(other.itemsMinor, itemsMinor) || other.itemsMinor == itemsMinor)&&(identical(other.sharedFromOnUsMinor, sharedFromOnUsMinor) || other.sharedFromOnUsMinor == sharedFromOnUsMinor)&&(identical(other.serviceMinor, serviceMinor) || other.serviceMinor == serviceMinor)&&(identical(other.tipMinor, tipMinor) || other.tipMinor == tipMinor)&&(identical(other.discountMinor, discountMinor) || other.discountMinor == discountMinor)&&(identical(other.finalMinor, finalMinor) || other.finalMinor == finalMinor)&&const DeepCollectionEquality().equals(other.lines, _lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,itemsMinor,sharedFromOnUsMinor,serviceMinor,tipMinor,discountMinor,finalMinor,const DeepCollectionEquality().hash(_lines));
}

@override
String toString() {
    return 'Breakdown(itemsMinor: $itemsMinor, sharedFromOnUsMinor: $sharedFromOnUsMinor, serviceMinor: $serviceMinor, tipMinor: $tipMinor, discountMinor: $discountMinor, finalMinor: $finalMinor, lines: $lines)';
}


}

/// @nodoc
abstract mixin class _$BreakdownCopyWith<$Res> implements $BreakdownCopyWith<$Res> {
  factory _$BreakdownCopyWith(_Breakdown value, $Res Function(_Breakdown) _then) = __$BreakdownCopyWithImpl;
@override @useResult
$Res call({
 int itemsMinor, int sharedFromOnUsMinor, int serviceMinor, int tipMinor, int discountMinor, int finalMinor, List<BreakdownLine> lines
});




}
/// @nodoc
class __$BreakdownCopyWithImpl<$Res>
    implements _$BreakdownCopyWith<$Res> {
  __$BreakdownCopyWithImpl(this._self, this._then);

  final _Breakdown _self;
  final $Res Function(_Breakdown) _then;

/// Create a copy of Breakdown
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? itemsMinor = null,Object? sharedFromOnUsMinor = null,Object? serviceMinor = null,Object? tipMinor = null,Object? discountMinor = null,Object? finalMinor = null,Object? lines = null,}) {
  return _then(_Breakdown(
itemsMinor: null == itemsMinor ? _self.itemsMinor : itemsMinor // ignore: cast_nullable_to_non_nullable
as int,sharedFromOnUsMinor: null == sharedFromOnUsMinor ? _self.sharedFromOnUsMinor : sharedFromOnUsMinor // ignore: cast_nullable_to_non_nullable
as int,serviceMinor: null == serviceMinor ? _self.serviceMinor : serviceMinor // ignore: cast_nullable_to_non_nullable
as int,tipMinor: null == tipMinor ? _self.tipMinor : tipMinor // ignore: cast_nullable_to_non_nullable
as int,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,finalMinor: null == finalMinor ? _self.finalMinor : finalMinor // ignore: cast_nullable_to_non_nullable
as int,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<BreakdownLine>,
  ));
}


}


/// @nodoc
mixin _$Computed {

 bool get ok; Map<String, Breakdown> get perParticipant; int? get totalMinor; List<Ambiguity> get problems;
/// Create a copy of Computed
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComputedCopyWith<Computed> get copyWith => _$ComputedCopyWithImpl<Computed>(this as Computed, _$identity);

  /// Serializes this Computed to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Computed;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Computed&&(identical(other.ok, _this.ok) || other.ok == _this.ok)&&const DeepCollectionEquality().equals(other.perParticipant, _this.perParticipant)&&(identical(other.totalMinor, _this.totalMinor) || other.totalMinor == _this.totalMinor)&&const DeepCollectionEquality().equals(other.problems, _this.problems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Computed;
  return Object.hash(runtimeType,_this.ok,const DeepCollectionEquality().hash(_this.perParticipant),_this.totalMinor,const DeepCollectionEquality().hash(_this.problems));
}

@override
String toString() {
  final _this = this as Computed;
  return 'Computed(ok: ${_this.ok}, perParticipant: ${_this.perParticipant}, totalMinor: ${_this.totalMinor}, problems: ${_this.problems})';
}


}

/// @nodoc
abstract mixin class $ComputedCopyWith<$Res>  {
  factory $ComputedCopyWith(Computed value, $Res Function(Computed) _then) = _$ComputedCopyWithImpl;
@useResult
$Res call({
 bool ok, Map<String, Breakdown> perParticipant, int? totalMinor, List<Ambiguity> problems
});




}
/// @nodoc
class _$ComputedCopyWithImpl<$Res>
    implements $ComputedCopyWith<$Res> {
  _$ComputedCopyWithImpl(this._self, this._then);

  final Computed _self;
  final $Res Function(Computed) _then;

/// Create a copy of Computed
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ok = null,Object? perParticipant = null,Object? totalMinor = freezed,Object? problems = null,}) {
  return _then(Computed(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,perParticipant: null == perParticipant ? _self.perParticipant : perParticipant // ignore: cast_nullable_to_non_nullable
as Map<String, Breakdown>,totalMinor: freezed == totalMinor ? _self.totalMinor : totalMinor // ignore: cast_nullable_to_non_nullable
as int?,problems: null == problems ? _self.problems : problems // ignore: cast_nullable_to_non_nullable
as List<Ambiguity>,
  ));
}

}


/// Adds pattern-matching-related methods to [Computed].
extension ComputedPatterns on Computed {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Computed value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Computed() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Computed value)  $default,){
final _that = this;
switch (_that) {
case _Computed():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Computed value)?  $default,){
final _that = this;
switch (_that) {
case _Computed() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool ok,  Map<String, Breakdown> perParticipant,  int? totalMinor,  List<Ambiguity> problems)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Computed() when $default != null:
return $default(_that.ok,_that.perParticipant,_that.totalMinor,_that.problems);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool ok,  Map<String, Breakdown> perParticipant,  int? totalMinor,  List<Ambiguity> problems)  $default,) {final _that = this;
switch (_that) {
case _Computed():
return $default(_that.ok,_that.perParticipant,_that.totalMinor,_that.problems);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool ok,  Map<String, Breakdown> perParticipant,  int? totalMinor,  List<Ambiguity> problems)?  $default,) {final _that = this;
switch (_that) {
case _Computed() when $default != null:
return $default(_that.ok,_that.perParticipant,_that.totalMinor,_that.problems);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Computed implements Computed {
  const _Computed({this.ok = false,  Map<String, Breakdown> perParticipant = const <String, Breakdown>{}, this.totalMinor,  List<Ambiguity> problems = const <Ambiguity>[]}): _perParticipant = perParticipant,_problems = problems;
  factory _Computed.fromJson(Map<String, dynamic> json) => _$ComputedFromJson(json);

@override@JsonKey() final  bool ok;
 final  Map<String, Breakdown> _perParticipant;
@override@JsonKey() Map<String, Breakdown> get perParticipant {
  if (_perParticipant is EqualUnmodifiableMapView) return _perParticipant;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_perParticipant);
}

@override final  int? totalMinor;
 final  List<Ambiguity> _problems;
@override@JsonKey() List<Ambiguity> get problems {
  if (_problems is EqualUnmodifiableListView) return _problems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_problems);
}


/// Create a copy of Computed
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComputedCopyWith<_Computed> get copyWith => __$ComputedCopyWithImpl<_Computed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ComputedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Computed&&(identical(other.ok, ok) || other.ok == ok)&&const DeepCollectionEquality().equals(other.perParticipant, _perParticipant)&&(identical(other.totalMinor, totalMinor) || other.totalMinor == totalMinor)&&const DeepCollectionEquality().equals(other.problems, _problems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ok,const DeepCollectionEquality().hash(_perParticipant),totalMinor,const DeepCollectionEquality().hash(_problems));
}

@override
String toString() {
    return 'Computed(ok: $ok, perParticipant: $perParticipant, totalMinor: $totalMinor, problems: $problems)';
}


}

/// @nodoc
abstract mixin class _$ComputedCopyWith<$Res> implements $ComputedCopyWith<$Res> {
  factory _$ComputedCopyWith(_Computed value, $Res Function(_Computed) _then) = __$ComputedCopyWithImpl;
@override @useResult
$Res call({
 bool ok, Map<String, Breakdown> perParticipant, int? totalMinor, List<Ambiguity> problems
});




}
/// @nodoc
class __$ComputedCopyWithImpl<$Res>
    implements _$ComputedCopyWith<$Res> {
  __$ComputedCopyWithImpl(this._self, this._then);

  final _Computed _self;
  final $Res Function(_Computed) _then;

/// Create a copy of Computed
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ok = null,Object? perParticipant = null,Object? totalMinor = freezed,Object? problems = null,}) {
  return _then(_Computed(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,perParticipant: null == perParticipant ? _self._perParticipant : perParticipant // ignore: cast_nullable_to_non_nullable
as Map<String, Breakdown>,totalMinor: freezed == totalMinor ? _self.totalMinor : totalMinor // ignore: cast_nullable_to_non_nullable
as int?,problems: null == problems ? _self._problems : problems // ignore: cast_nullable_to_non_nullable
as List<Ambiguity>,
  ));
}


}


/// @nodoc
mixin _$Split {

 String get id; String get title; String? get merchant;/// ISO date, e.g. 2026-10-02.
 String? get receiptDate;/// draft, claiming, collecting, settled or cancelled.
 String get status; Receipt get receipt; List<Ambiguity> get receiptAmbiguities; Map<String, List<Claim>> get claims; Rules get rules; String get organiserParticipantId; Computed? get computed;@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get createdAt;@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? get updatedAt;
/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitCopyWith<Split> get copyWith => _$SplitCopyWithImpl<Split>(this as Split, _$identity);

  /// Serializes this Split to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Split;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Split&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.merchant, _this.merchant) || other.merchant == _this.merchant)&&(identical(other.receiptDate, _this.receiptDate) || other.receiptDate == _this.receiptDate)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.receipt, _this.receipt) || other.receipt == _this.receipt)&&const DeepCollectionEquality().equals(other.receiptAmbiguities, _this.receiptAmbiguities)&&const DeepCollectionEquality().equals(other.claims, _this.claims)&&(identical(other.rules, _this.rules) || other.rules == _this.rules)&&(identical(other.organiserParticipantId, _this.organiserParticipantId) || other.organiserParticipantId == _this.organiserParticipantId)&&(identical(other.computed, _this.computed) || other.computed == _this.computed)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Split;
  return Object.hash(runtimeType,_this.id,_this.title,_this.merchant,_this.receiptDate,_this.status,_this.receipt,const DeepCollectionEquality().hash(_this.receiptAmbiguities),const DeepCollectionEquality().hash(_this.claims),_this.rules,_this.organiserParticipantId,_this.computed,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Split;
  return 'Split(id: ${_this.id}, title: ${_this.title}, merchant: ${_this.merchant}, receiptDate: ${_this.receiptDate}, status: ${_this.status}, receipt: ${_this.receipt}, receiptAmbiguities: ${_this.receiptAmbiguities}, claims: ${_this.claims}, rules: ${_this.rules}, organiserParticipantId: ${_this.organiserParticipantId}, computed: ${_this.computed}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $SplitCopyWith<$Res>  {
  factory $SplitCopyWith(Split value, $Res Function(Split) _then) = _$SplitCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? merchant, String? receiptDate, String status, Receipt receipt, List<Ambiguity> receiptAmbiguities, Map<String, List<Claim>> claims, Rules rules, String organiserParticipantId, Computed? computed,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? createdAt,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});


$ReceiptCopyWith<$Res> get receipt;$RulesCopyWith<$Res> get rules;$ComputedCopyWith<$Res>? get computed;

}
/// @nodoc
class _$SplitCopyWithImpl<$Res>
    implements $SplitCopyWith<$Res> {
  _$SplitCopyWithImpl(this._self, this._then);

  final Split _self;
  final $Res Function(Split) _then;

/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? merchant = freezed,Object? receiptDate = freezed,Object? status = null,Object? receipt = null,Object? receiptAmbiguities = null,Object? claims = null,Object? rules = null,Object? organiserParticipantId = null,Object? computed = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(Split(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,merchant: freezed == merchant ? _self.merchant : merchant // ignore: cast_nullable_to_non_nullable
as String?,receiptDate: freezed == receiptDate ? _self.receiptDate : receiptDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,receipt: null == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as Receipt,receiptAmbiguities: null == receiptAmbiguities ? _self.receiptAmbiguities : receiptAmbiguities // ignore: cast_nullable_to_non_nullable
as List<Ambiguity>,claims: null == claims ? _self.claims : claims // ignore: cast_nullable_to_non_nullable
as Map<String, List<Claim>>,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as Rules,organiserParticipantId: null == organiserParticipantId ? _self.organiserParticipantId : organiserParticipantId // ignore: cast_nullable_to_non_nullable
as String,computed: freezed == computed ? _self.computed : computed // ignore: cast_nullable_to_non_nullable
as Computed?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReceiptCopyWith<$Res> get receipt {
  
  return $ReceiptCopyWith<$Res>(_self.receipt, (value) {
    return _then(_self.copyWith(receipt: value));
  });
}/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulesCopyWith<$Res> get rules {
  
  return $RulesCopyWith<$Res>(_self.rules, (value) {
    return _then(_self.copyWith(rules: value));
  });
}/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ComputedCopyWith<$Res>? get computed {
    if (_self.computed == null) {
    return null;
  }

  return $ComputedCopyWith<$Res>(_self.computed!, (value) {
    return _then(_self.copyWith(computed: value));
  });
}
}


/// Adds pattern-matching-related methods to [Split].
extension SplitPatterns on Split {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Split value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Split() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Split value)  $default,){
final _that = this;
switch (_that) {
case _Split():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Split value)?  $default,){
final _that = this;
switch (_that) {
case _Split() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? merchant,  String? receiptDate,  String status,  Receipt receipt,  List<Ambiguity> receiptAmbiguities,  Map<String, List<Claim>> claims,  Rules rules,  String organiserParticipantId,  Computed? computed, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? createdAt, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Split() when $default != null:
return $default(_that.id,_that.title,_that.merchant,_that.receiptDate,_that.status,_that.receipt,_that.receiptAmbiguities,_that.claims,_that.rules,_that.organiserParticipantId,_that.computed,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? merchant,  String? receiptDate,  String status,  Receipt receipt,  List<Ambiguity> receiptAmbiguities,  Map<String, List<Claim>> claims,  Rules rules,  String organiserParticipantId,  Computed? computed, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? createdAt, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Split():
return $default(_that.id,_that.title,_that.merchant,_that.receiptDate,_that.status,_that.receipt,_that.receiptAmbiguities,_that.claims,_that.rules,_that.organiserParticipantId,_that.computed,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? merchant,  String? receiptDate,  String status,  Receipt receipt,  List<Ambiguity> receiptAmbiguities,  Map<String, List<Claim>> claims,  Rules rules,  String organiserParticipantId,  Computed? computed, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? createdAt, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Split() when $default != null:
return $default(_that.id,_that.title,_that.merchant,_that.receiptDate,_that.status,_that.receipt,_that.receiptAmbiguities,_that.claims,_that.rules,_that.organiserParticipantId,_that.computed,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Split extends Split {
  const _Split({required this.id, this.title = 'Your bill', this.merchant, this.receiptDate, this.status = 'draft', this.receipt = const Receipt(),  List<Ambiguity> receiptAmbiguities = const <Ambiguity>[],  Map<String, List<Claim>> claims = const <String, List<Claim>>{}, this.rules = const Rules(), this.organiserParticipantId = '', this.computed, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.createdAt, @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.updatedAt}): _receiptAmbiguities = receiptAmbiguities,_claims = claims,super._();
  factory _Split.fromJson(Map<String, dynamic> json) => _$SplitFromJson(json);

@override final  String id;
@override@JsonKey() final  String title;
@override final  String? merchant;
/// ISO date, e.g. 2026-10-02.
@override final  String? receiptDate;
/// draft, claiming, collecting, settled or cancelled.
@override@JsonKey() final  String status;
@override@JsonKey() final  Receipt receipt;
 final  List<Ambiguity> _receiptAmbiguities;
@override@JsonKey() List<Ambiguity> get receiptAmbiguities {
  if (_receiptAmbiguities is EqualUnmodifiableListView) return _receiptAmbiguities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_receiptAmbiguities);
}

 final  Map<String, List<Claim>> _claims;
@override@JsonKey() Map<String, List<Claim>> get claims {
  if (_claims is EqualUnmodifiableMapView) return _claims;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_claims);
}

@override@JsonKey() final  Rules rules;
@override@JsonKey() final  String organiserParticipantId;
@override final  Computed? computed;
@override@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? createdAt;
@override@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) final  DateTime? updatedAt;

/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SplitCopyWith<_Split> get copyWith => __$SplitCopyWithImpl<_Split>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SplitToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Split&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.merchant, merchant) || other.merchant == merchant)&&(identical(other.receiptDate, receiptDate) || other.receiptDate == receiptDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.receipt, receipt) || other.receipt == receipt)&&const DeepCollectionEquality().equals(other.receiptAmbiguities, _receiptAmbiguities)&&const DeepCollectionEquality().equals(other.claims, _claims)&&(identical(other.rules, rules) || other.rules == rules)&&(identical(other.organiserParticipantId, organiserParticipantId) || other.organiserParticipantId == organiserParticipantId)&&(identical(other.computed, computed) || other.computed == computed)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,merchant,receiptDate,status,receipt,const DeepCollectionEquality().hash(_receiptAmbiguities),const DeepCollectionEquality().hash(_claims),rules,organiserParticipantId,computed,createdAt,updatedAt);
}

@override
String toString() {
    return 'Split(id: $id, title: $title, merchant: $merchant, receiptDate: $receiptDate, status: $status, receipt: $receipt, receiptAmbiguities: $receiptAmbiguities, claims: $claims, rules: $rules, organiserParticipantId: $organiserParticipantId, computed: $computed, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SplitCopyWith<$Res> implements $SplitCopyWith<$Res> {
  factory _$SplitCopyWith(_Split value, $Res Function(_Split) _then) = __$SplitCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? merchant, String? receiptDate, String status, Receipt receipt, List<Ambiguity> receiptAmbiguities, Map<String, List<Claim>> claims, Rules rules, String organiserParticipantId, Computed? computed,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? createdAt,@JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) DateTime? updatedAt
});


@override $ReceiptCopyWith<$Res> get receipt;@override $RulesCopyWith<$Res> get rules;@override $ComputedCopyWith<$Res>? get computed;

}
/// @nodoc
class __$SplitCopyWithImpl<$Res>
    implements _$SplitCopyWith<$Res> {
  __$SplitCopyWithImpl(this._self, this._then);

  final _Split _self;
  final $Res Function(_Split) _then;

/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? merchant = freezed,Object? receiptDate = freezed,Object? status = null,Object? receipt = null,Object? receiptAmbiguities = null,Object? claims = null,Object? rules = null,Object? organiserParticipantId = null,Object? computed = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Split(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,merchant: freezed == merchant ? _self.merchant : merchant // ignore: cast_nullable_to_non_nullable
as String?,receiptDate: freezed == receiptDate ? _self.receiptDate : receiptDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,receipt: null == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as Receipt,receiptAmbiguities: null == receiptAmbiguities ? _self._receiptAmbiguities : receiptAmbiguities // ignore: cast_nullable_to_non_nullable
as List<Ambiguity>,claims: null == claims ? _self._claims : claims // ignore: cast_nullable_to_non_nullable
as Map<String, List<Claim>>,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as Rules,organiserParticipantId: null == organiserParticipantId ? _self.organiserParticipantId : organiserParticipantId // ignore: cast_nullable_to_non_nullable
as String,computed: freezed == computed ? _self.computed : computed // ignore: cast_nullable_to_non_nullable
as Computed?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReceiptCopyWith<$Res> get receipt {
  
  return $ReceiptCopyWith<$Res>(_self.receipt, (value) {
    return _then(_self.copyWith(receipt: value));
  });
}/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RulesCopyWith<$Res> get rules {
  
  return $RulesCopyWith<$Res>(_self.rules, (value) {
    return _then(_self.copyWith(rules: value));
  });
}/// Create a copy of Split
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ComputedCopyWith<$Res>? get computed {
    if (_self.computed == null) {
    return null;
  }

  return $ComputedCopyWith<$Res>(_self.computed!, (value) {
    return _then(_self.copyWith(computed: value));
  });
}
}

// dart format on
