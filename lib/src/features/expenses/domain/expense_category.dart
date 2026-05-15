// lib/src/features/expenses/domain/expense_category.dart
//
// Direct-expense categories. The wire `value` is what we persist; the `label`
// is what we render in chips, summaries, and activity entries.

import '../../../l10n/generated/app_localizations.dart';

enum ExpenseCategory {
  feed('feed', 'Feed'),
  medicine('medicine', 'Medicine'),
  labor('labor', 'Labor'),
  utilities('utilities', 'Utilities'),
  equipment('equipment', 'Equipment'),
  maintenance('maintenance', 'Maintenance'),
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);

  final String value;
  final String label;

  static ExpenseCategory fromString(String s) =>
      ExpenseCategory.values.firstWhere(
        (e) => e.value == s,
        orElse: () => ExpenseCategory.other,
      );
}

/// Returns the localized display label for an [ExpenseCategory]. The enum's
/// [ExpenseCategory.label] stays as the English wire/display fallback for
/// non-UI callers (activity entries, repositories, tests).
String localizedExpenseCategory(AppLocalizations l, ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.feed:
      return l.expense_category_feed;
    case ExpenseCategory.medicine:
      return l.expense_category_medicine;
    case ExpenseCategory.labor:
      return l.expense_category_labor;
    case ExpenseCategory.utilities:
      return l.expense_category_utilities;
    case ExpenseCategory.equipment:
      return l.expense_category_equipment;
    case ExpenseCategory.maintenance:
      return l.expense_category_maintenance;
    case ExpenseCategory.other:
      return l.expense_category_other;
  }
}
