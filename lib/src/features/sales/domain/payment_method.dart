enum PaymentMethod {
  cash('cash', 'Cash'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  gcash('gcash', 'GCash'),
  check('check', 'Check'),
  other('other', 'Other');

  const PaymentMethod(this.value, this.label);
  final String value;
  final String label;

  static PaymentMethod fromString(String s) => PaymentMethod.values.firstWhere(
        (e) => e.value == s,
        orElse: () => PaymentMethod.cash,
      );
}
