// lib/src/features/expenses/domain/expense_category.dart
//
// Direct-expense categories. The wire `value` is what we persist; the `label`
// is what we render in chips, summaries, and activity entries.

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
