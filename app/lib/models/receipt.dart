import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt.freezed.dart';
part 'receipt.g.dart';

/// One printed line. The printed line total is the truth.
@freezed
abstract class ReceiptLine with _$ReceiptLine {
  const factory ReceiptLine({
    required String id,
    required String name,
    @Default(1) int qty,

    /// Null while the price could not be read. Never shown as £0.00.
    int? lineTotalMinor,
  }) = _ReceiptLine;

  factory ReceiptLine.fromJson(Map<String, dynamic> json) => _$ReceiptLineFromJson(json);
}

@freezed
abstract class Discount with _$Discount {
  const factory Discount({required String label, required int amountMinor}) = _Discount;

  factory Discount.fromJson(Map<String, dynamic> json) => _$DiscountFromJson(json);
}

@freezed
abstract class Receipt with _$Receipt {
  const factory Receipt({
    @Default(<ReceiptLine>[]) List<ReceiptLine> lines,
    @Default(0) int serviceChargeMinor,
    String? serviceChargeLabel,
    @Default(0) int tipMinor,
    @Default(<Discount>[]) List<Discount> discounts,

    /// Null while the total could not be read.
    int? printedTotalMinor,
    @Default('GBP') String currency,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);
}
