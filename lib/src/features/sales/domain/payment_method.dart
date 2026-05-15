import '../../../l10n/generated/app_localizations.dart';

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

/// Returns the localized display label for a [PaymentMethod]. The enum's
/// [PaymentMethod.label] stays as the English wire/display fallback for
/// non-UI callers (logs, repositories, tests).
String localizedPaymentMethod(AppLocalizations l, PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return l.payment_method_cash;
    case PaymentMethod.bankTransfer:
      return l.payment_method_bank_transfer;
    case PaymentMethod.gcash:
      return l.payment_method_gcash;
    case PaymentMethod.check:
      return l.payment_method_check;
    case PaymentMethod.other:
      return l.payment_method_other;
  }
}
