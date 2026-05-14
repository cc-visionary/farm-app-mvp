// lib/src/features/expenses/presentation/expenses_list_screen.dart
//
// Direct expenses, filtered by category. Filter chips wrap (not horizontal
// scroll) so every category is visible on first paint. A running-total bar
// at the top sums whatever is currently displayed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'log_expense_screen.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() =>
      _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  ExpenseCategory? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log expense'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogExpenseScreen()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values
                  .map(
                    (c) => FilterChip(
                      label: Text(c.label),
                      selected: _categoryFilter == c,
                      onSelected: (sel) => setState(
                        () => _categoryFilter = sel ? c : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (list) {
                final filtered = _categoryFilter == null
                    ? list
                    : list
                        .where((e) => e.category == _categoryFilter)
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Iconsax.receipt_item,
                    title: list.isEmpty
                        ? 'No expenses logged'
                        : 'No matching expenses',
                    subtitle: list.isEmpty
                        ? 'Tap "Log expense" to record your first expense.'
                        : 'Try clearing the category filter.',
                  );
                }
                final total = filtered.fold<double>(
                  0,
                  (s, e) => s + e.amountPhp,
                );
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      width: double.infinity,
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Text('Total', style: theme.textTheme.titleMedium),
                          const Spacer(),
                          Text(
                            '₱${total.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _ExpenseCard(expense: filtered[i]),
                      ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(
          expense.description,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${expense.category.label} · '
          '${DateFormat.yMMMd().format(expense.date.toDate())}',
        ),
        trailing: Text(
          '₱${expense.amountPhp.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
