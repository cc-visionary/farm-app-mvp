enum PaymentStatus {
  paid('paid', 'Paid'),
  partial('partial', 'Partial'),
  unpaid('unpaid', 'Unpaid');

  const PaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static PaymentStatus fromString(String s) => PaymentStatus.values.firstWhere(
        (e) => e.value == s,
        orElse: () => PaymentStatus.paid,
      );
}
