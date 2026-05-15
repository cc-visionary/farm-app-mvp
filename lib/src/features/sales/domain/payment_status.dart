import '../../../l10n/generated/app_localizations.dart';

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

/// Returns the localized display label for a [PaymentStatus]. The enum's
/// [PaymentStatus.label] stays as the English wire/display fallback for
/// non-UI callers (logs, repositories, tests).
String localizedPaymentStatus(AppLocalizations l, PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid:
      return l.payment_status_paid;
    case PaymentStatus.partial:
      return l.payment_status_partial;
    case PaymentStatus.unpaid:
      return l.payment_status_unpaid;
  }
}
