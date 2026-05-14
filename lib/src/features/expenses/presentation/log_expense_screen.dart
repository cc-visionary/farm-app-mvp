// lib/src/features/expenses/presentation/log_expense_screen.dart
//
// Form for logging a direct expense. v1 keeps the form intentionally small:
// category (ChoiceChips), description, amount, date, optional notes. The
// model supports optional batch / pig / area / equipment attribution but
// the picker UIs are deferred to a follow-up so this screen ships fast.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense_category.dart';

class LogExpenseScreen extends ConsumerStatefulWidget {
  const LogExpenseScreen({super.key});

  @override
  ConsumerState<LogExpenseScreen> createState() => _LogExpenseScreenState();
}

class _LogExpenseScreenState extends ConsumerState<LogExpenseScreen> {
  ExpenseCategory _category = ExpenseCategory.other;
  final _description = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final desc = _description.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (desc.isEmpty) {
      _snack('Description is required.');
      return;
    }
    if (amount == null || amount <= 0) {
      _snack('Amount must be a positive number.');
      return;
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(expenseRepositoryProvider).createExpense(
            farmId: farmId,
            category: _category,
            description: desc,
            amountPhp: amount,
            date: Timestamp.fromDate(_date),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            actorUserId: user.uid,
            actorDisplayName: actorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'CATEGORY',
              padding: EdgeInsets.only(bottom: 8),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  )
                  .toList(),
            ),
            const SectionHeader(title: 'DESCRIPTION'),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                hintText: 'What was this expense for?',
              ),
            ),
            const SectionHeader(title: 'AMOUNT'),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₱ '),
            ),
            const SectionHeader(title: 'DATE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_date.year}-'
                '${_date.month.toString().padLeft(2, '0')}-'
                '${_date.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Iconsax.calendar),
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context,
                  initial: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SectionHeader(title: 'NOTES'),
            TextField(controller: _notes, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
