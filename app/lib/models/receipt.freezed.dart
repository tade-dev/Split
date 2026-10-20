// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'receipt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReceiptLine {

 String get id; String get name; int get qty;/// Null while the price could not be read. Never shown as £0.00.
 int? get lineTotalMinor;
/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceiptLineCopyWith<ReceiptLine> get copyWith => _$ReceiptLineCopyWithImpl<ReceiptLine>(this as ReceiptLine, _$identity);

  /// Serializes this ReceiptLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReceiptLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceiptLine&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.qty, _this.qty) || other.qty == _this.qty)&&(identical(other.lineTotalMinor, _this.lineTotalMinor) || other.lineTotalMinor == _this.lineTotalMinor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReceiptLine;
  return Object.hash(runtimeType,_this.id,_this.name,_this.qty,_this.lineTotalMinor);
}

@override
String toString() {
  final _this = this as ReceiptLine;
  return 'ReceiptLine(id: ${_this.id}, name: ${_this.name}, qty: ${_this.qty}, lineTotalMinor: ${_this.lineTotalMinor})';
}


}

/// @nodoc
abstract mixin class $ReceiptLineCopyWith<$Res>  {
  factory $ReceiptLineCopyWith(ReceiptLine value, $Res Function(ReceiptLine) _then) = _$ReceiptLineCopyWithImpl;
@useResult
$Res call({
 String id, String name, int qty, int? lineTotalMinor
});




}
/// @nodoc
class _$ReceiptLineCopyWithImpl<$Res>
    implements $ReceiptLineCopyWith<$Res> {
  _$ReceiptLineCopyWithImpl(this._self, this._then);

  final ReceiptLine _self;
  final $Res Function(ReceiptLine) _then;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? qty = null,Object? lineTotalMinor = freezed,}) {
  return _then(ReceiptLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,lineTotalMinor: freezed == lineTotalMinor ? _self.lineTotalMinor : lineTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceiptLine].
extension ReceiptLinePatterns on ReceiptLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceiptLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceiptLine value)  $default,){
final _that = this;
switch (_that) {
case _ReceiptLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceiptLine value)?  $default,){
final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int qty,  int? lineTotalMinor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
return $default(_that.id,_that.name,_that.qty,_that.lineTotalMinor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int qty,  int? lineTotalMinor)  $default,) {final _that = this;
switch (_that) {
case _ReceiptLine():
return $default(_that.id,_that.name,_that.qty,_that.lineTotalMinor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int qty,  int? lineTotalMinor)?  $default,) {final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
return $default(_that.id,_that.name,_that.qty,_that.lineTotalMinor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceiptLine implements ReceiptLine {
  const _ReceiptLine({required this.id, required this.name, this.qty = 1, this.lineTotalMinor});
  factory _ReceiptLine.fromJson(Map<String, dynamic> json) => _$ReceiptLineFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int qty;
/// Null while the price could not be read. Never shown as £0.00.
@override final  int? lineTotalMinor;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceiptLineCopyWith<_ReceiptLine> get copyWith => __$ReceiptLineCopyWithImpl<_ReceiptLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceiptLineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceiptLine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.qty, qty) || other.qty == qty)&&(identical(other.lineTotalMinor, lineTotalMinor) || other.lineTotalMinor == lineTotalMinor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,qty,lineTotalMinor);
}

@override
String toString() {
    return 'ReceiptLine(id: $id, name: $name, qty: $qty, lineTotalMinor: $lineTotalMinor)';
}


}

/// @nodoc
abstract mixin class _$ReceiptLineCopyWith<$Res> implements $ReceiptLineCopyWith<$Res> {
  factory _$ReceiptLineCopyWith(_ReceiptLine value, $Res Function(_ReceiptLine) _then) = __$ReceiptLineCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int qty, int? lineTotalMinor
});




}
/// @nodoc
class __$ReceiptLineCopyWithImpl<$Res>
    implements _$ReceiptLineCopyWith<$Res> {
  __$ReceiptLineCopyWithImpl(this._self, this._then);

  final _ReceiptLine _self;
  final $Res Function(_ReceiptLine) _then;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? qty = null,Object? lineTotalMinor = freezed,}) {
  return _then(_ReceiptLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,lineTotalMinor: freezed == lineTotalMinor ? _self.lineTotalMinor : lineTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$Discount {

 String get label; int get amountMinor;
/// Create a copy of Discount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscountCopyWith<Discount> get copyWith => _$DiscountCopyWithImpl<Discount>(this as Discount, _$identity);

  /// Serializes this Discount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Discount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Discount&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.amountMinor, _this.amountMinor) || other.amountMinor == _this.amountMinor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Discount;
  return Object.hash(runtimeType,_this.label,_this.amountMinor);
}

@override
String toString() {
  final _this = this as Discount;
  return 'Discount(label: ${_this.label}, amountMinor: ${_this.amountMinor})';
}


}

/// @nodoc
abstract mixin class $DiscountCopyWith<$Res>  {
  factory $DiscountCopyWith(Discount value, $Res Function(Discount) _then) = _$DiscountCopyWithImpl;
@useResult
$Res call({
 String label, int amountMinor
});




}
/// @nodoc
class _$DiscountCopyWithImpl<$Res>
    implements $DiscountCopyWith<$Res> {
  _$DiscountCopyWithImpl(this._self, this._then);

  final Discount _self;
  final $Res Function(Discount) _then;

/// Create a copy of Discount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? amountMinor = null,}) {
  return _then(Discount(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Discount].
extension DiscountPatterns on Discount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Discount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Discount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Discount value)  $default,){
final _that = this;
switch (_that) {
case _Discount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Discount value)?  $default,){
final _that = this;
switch (_that) {
case _Discount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  int amountMinor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Discount() when $default != null:
return $default(_that.label,_that.amountMinor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  int amountMinor)  $default,) {final _that = this;
switch (_that) {
case _Discount():
return $default(_that.label,_that.amountMinor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  int amountMinor)?  $default,) {final _that = this;
switch (_that) {
case _Discount() when $default != null:
return $default(_that.label,_that.amountMinor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Discount implements Discount {
  const _Discount({required this.label, required this.amountMinor});
  factory _Discount.fromJson(Map<String, dynamic> json) => _$DiscountFromJson(json);

@override final  String label;
@override final  int amountMinor;

/// Create a copy of Discount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscountCopyWith<_Discount> get copyWith => __$DiscountCopyWithImpl<_Discount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiscountToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Discount&&(identical(other.label, label) || other.label == label)&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,label,amountMinor);
}

@override
String toString() {
    return 'Discount(label: $label, amountMinor: $amountMinor)';
}


}

/// @nodoc
abstract mixin class _$DiscountCopyWith<$Res> implements $DiscountCopyWith<$Res> {
  factory _$DiscountCopyWith(_Discount value, $Res Function(_Discount) _then) = __$DiscountCopyWithImpl;
@override @useResult
$Res call({
 String label, int amountMinor
});




}
/// @nodoc
class __$DiscountCopyWithImpl<$Res>
    implements _$DiscountCopyWith<$Res> {
  __$DiscountCopyWithImpl(this._self, this._then);

  final _Discount _self;
  final $Res Function(_Discount) _then;

/// Create a copy of Discount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? amountMinor = null,}) {
  return _then(_Discount(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Receipt {

 List<ReceiptLine> get lines; int get serviceChargeMinor; String? get serviceChargeLabel; int get tipMinor; List<Discount> get discounts;/// Null while the total could not be read.
 int? get printedTotalMinor; String get currency;
/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceiptCopyWith<Receipt> get copyWith => _$ReceiptCopyWithImpl<Receipt>(this as Receipt, _$identity);

  /// Serializes this Receipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Receipt;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Receipt&&const DeepCollectionEquality().equals(other.lines, _this.lines)&&(identical(other.serviceChargeMinor, _this.serviceChargeMinor) || other.serviceChargeMinor == _this.serviceChargeMinor)&&(identical(other.serviceChargeLabel, _this.serviceChargeLabel) || other.serviceChargeLabel == _this.serviceChargeLabel)&&(identical(other.tipMinor, _this.tipMinor) || other.tipMinor == _this.tipMinor)&&const DeepCollectionEquality().equals(other.discounts, _this.discounts)&&(identical(other.printedTotalMinor, _this.printedTotalMinor) || other.printedTotalMinor == _this.printedTotalMinor)&&(identical(other.currency, _this.currency) || other.currency == _this.currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Receipt;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.lines),_this.serviceChargeMinor,_this.serviceChargeLabel,_this.tipMinor,const DeepCollectionEquality().hash(_this.discounts),_this.printedTotalMinor,_this.currency);
}

@override
String toString() {
  final _this = this as Receipt;
  return 'Receipt(lines: ${_this.lines}, serviceChargeMinor: ${_this.serviceChargeMinor}, serviceChargeLabel: ${_this.serviceChargeLabel}, tipMinor: ${_this.tipMinor}, discounts: ${_this.discounts}, printedTotalMinor: ${_this.printedTotalMinor}, currency: ${_this.currency})';
}


}

/// @nodoc
abstract mixin class $ReceiptCopyWith<$Res>  {
  factory $ReceiptCopyWith(Receipt value, $Res Function(Receipt) _then) = _$ReceiptCopyWithImpl;
@useResult
$Res call({
 List<ReceiptLine> lines, int serviceChargeMinor, String? serviceChargeLabel, int tipMinor, List<Discount> discounts, int? printedTotalMinor, String currency
});




}
/// @nodoc
class _$ReceiptCopyWithImpl<$Res>
    implements $ReceiptCopyWith<$Res> {
  _$ReceiptCopyWithImpl(this._self, this._then);

  final Receipt _self;
  final $Res Function(Receipt) _then;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? serviceChargeMinor = null,Object? serviceChargeLabel = freezed,Object? tipMinor = null,Object? discounts = null,Object? printedTotalMinor = freezed,Object? currency = null,}) {
  return _then(Receipt(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,serviceChargeMinor: null == serviceChargeMinor ? _self.serviceChargeMinor : serviceChargeMinor // ignore: cast_nullable_to_non_nullable
as int,serviceChargeLabel: freezed == serviceChargeLabel ? _self.serviceChargeLabel : serviceChargeLabel // ignore: cast_nullable_to_non_nullable
as String?,tipMinor: null == tipMinor ? _self.tipMinor : tipMinor // ignore: cast_nullable_to_non_nullable
as int,discounts: null == discounts ? _self.discounts : discounts // ignore: cast_nullable_to_non_nullable
as List<Discount>,printedTotalMinor: freezed == printedTotalMinor ? _self.printedTotalMinor : printedTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Receipt].
extension ReceiptPatterns on Receipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Receipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Receipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Receipt value)  $default,){
final _that = this;
switch (_that) {
case _Receipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Receipt value)?  $default,){
final _that = this;
switch (_that) {
case _Receipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ReceiptLine> lines,  int serviceChargeMinor,  String? serviceChargeLabel,  int tipMinor,  List<Discount> discounts,  int? printedTotalMinor,  String currency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Receipt() when $default != null:
return $default(_that.lines,_that.serviceChargeMinor,_that.serviceChargeLabel,_that.tipMinor,_that.discounts,_that.printedTotalMinor,_that.currency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ReceiptLine> lines,  int serviceChargeMinor,  String? serviceChargeLabel,  int tipMinor,  List<Discount> discounts,  int? printedTotalMinor,  String currency)  $default,) {final _that = this;
switch (_that) {
case _Receipt():
return $default(_that.lines,_that.serviceChargeMinor,_that.serviceChargeLabel,_that.tipMinor,_that.discounts,_that.printedTotalMinor,_that.currency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ReceiptLine> lines,  int serviceChargeMinor,  String? serviceChargeLabel,  int tipMinor,  List<Discount> discounts,  int? printedTotalMinor,  String currency)?  $default,) {final _that = this;
switch (_that) {
case _Receipt() when $default != null:
return $default(_that.lines,_that.serviceChargeMinor,_that.serviceChargeLabel,_that.tipMinor,_that.discounts,_that.printedTotalMinor,_that.currency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Receipt implements Receipt {
  const _Receipt({ List<ReceiptLine> lines = const <ReceiptLine>[], this.serviceChargeMinor = 0, this.serviceChargeLabel, this.tipMinor = 0,  List<Discount> discounts = const <Discount>[], this.printedTotalMinor, this.currency = 'GBP'}): _lines = lines,_discounts = discounts;
  factory _Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);

 final  List<ReceiptLine> _lines;
@override@JsonKey() List<ReceiptLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override@JsonKey() final  int serviceChargeMinor;
@override final  String? serviceChargeLabel;
@override@JsonKey() final  int tipMinor;
 final  List<Discount> _discounts;
@override@JsonKey() List<Discount> get discounts {
  if (_discounts is EqualUnmodifiableListView) return _discounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_discounts);
}

/// Null while the total could not be read.
@override final  int? printedTotalMinor;
@override@JsonKey() final  String currency;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceiptCopyWith<_Receipt> get copyWith => __$ReceiptCopyWithImpl<_Receipt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceiptToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Receipt&&const DeepCollectionEquality().equals(other.lines, _lines)&&(identical(other.serviceChargeMinor, serviceChargeMinor) || other.serviceChargeMinor == serviceChargeMinor)&&(identical(other.serviceChargeLabel, serviceChargeLabel) || other.serviceChargeLabel == serviceChargeLabel)&&(identical(other.tipMinor, tipMinor) || other.tipMinor == tipMinor)&&const DeepCollectionEquality().equals(other.discounts, _discounts)&&(identical(other.printedTotalMinor, printedTotalMinor) || other.printedTotalMinor == printedTotalMinor)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),serviceChargeMinor,serviceChargeLabel,tipMinor,const DeepCollectionEquality().hash(_discounts),printedTotalMinor,currency);
}

@override
String toString() {
    return 'Receipt(lines: $lines, serviceChargeMinor: $serviceChargeMinor, serviceChargeLabel: $serviceChargeLabel, tipMinor: $tipMinor, discounts: $discounts, printedTotalMinor: $printedTotalMinor, currency: $currency)';
}


}

/// @nodoc
abstract mixin class _$ReceiptCopyWith<$Res> implements $ReceiptCopyWith<$Res> {
  factory _$ReceiptCopyWith(_Receipt value, $Res Function(_Receipt) _then) = __$ReceiptCopyWithImpl;
@override @useResult
$Res call({
 List<ReceiptLine> lines, int serviceChargeMinor, String? serviceChargeLabel, int tipMinor, List<Discount> discounts, int? printedTotalMinor, String currency
});




}
/// @nodoc
class __$ReceiptCopyWithImpl<$Res>
    implements _$ReceiptCopyWith<$Res> {
  __$ReceiptCopyWithImpl(this._self, this._then);

  final _Receipt _self;
  final $Res Function(_Receipt) _then;

/// Create a copy of Receipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? serviceChargeMinor = null,Object? serviceChargeLabel = freezed,Object? tipMinor = null,Object? discounts = null,Object? printedTotalMinor = freezed,Object? currency = null,}) {
  return _then(_Receipt(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,serviceChargeMinor: null == serviceChargeMinor ? _self.serviceChargeMinor : serviceChargeMinor // ignore: cast_nullable_to_non_nullable
as int,serviceChargeLabel: freezed == serviceChargeLabel ? _self.serviceChargeLabel : serviceChargeLabel // ignore: cast_nullable_to_non_nullable
as String?,tipMinor: null == tipMinor ? _self.tipMinor : tipMinor // ignore: cast_nullable_to_non_nullable
as int,discounts: null == discounts ? _self._discounts : discounts // ignore: cast_nullable_to_non_nullable
as List<Discount>,printedTotalMinor: freezed == printedTotalMinor ? _self.printedTotalMinor : printedTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
