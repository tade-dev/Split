// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReceiptLine _$ReceiptLineFromJson(Map<String, dynamic> json) => _ReceiptLine(
  id: json['id'] as String,
  name: json['name'] as String,
  qty: (json['qty'] as num?)?.toInt() ?? 1,
  lineTotalMinor: (json['lineTotalMinor'] as num?)?.toInt(),
);

Map<String, dynamic> _$ReceiptLineToJson(_ReceiptLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'qty': instance.qty,
      'lineTotalMinor': instance.lineTotalMinor,
    };

_Discount _$DiscountFromJson(Map<String, dynamic> json) => _Discount(
  label: json['label'] as String,
  amountMinor: (json['amountMinor'] as num).toInt(),
);

Map<String, dynamic> _$DiscountToJson(_Discount instance) => <String, dynamic>{
  'label': instance.label,
  'amountMinor': instance.amountMinor,
};

_Receipt _$ReceiptFromJson(Map<String, dynamic> json) => _Receipt(
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ReceiptLine>[],
  serviceChargeMinor: (json['serviceChargeMinor'] as num?)?.toInt() ?? 0,
  serviceChargeLabel: json['serviceChargeLabel'] as String?,
  tipMinor: (json['tipMinor'] as num?)?.toInt() ?? 0,
  discounts:
      (json['discounts'] as List<dynamic>?)
          ?.map((e) => Discount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Discount>[],
  printedTotalMinor: (json['printedTotalMinor'] as num?)?.toInt(),
  currency: json['currency'] as String? ?? 'GBP',
);

Map<String, dynamic> _$ReceiptToJson(_Receipt instance) => <String, dynamic>{
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'serviceChargeMinor': instance.serviceChargeMinor,
  'serviceChargeLabel': instance.serviceChargeLabel,
  'tipMinor': instance.tipMinor,
  'discounts': instance.discounts.map((e) => e.toJson()).toList(),
  'printedTotalMinor': instance.printedTotalMinor,
  'currency': instance.currency,
};
