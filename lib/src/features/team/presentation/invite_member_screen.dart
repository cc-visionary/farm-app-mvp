import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});
  @override
  ConsumerState<InviteMemberScreen> createState() => _S();
}

class _S extends ConsumerState<InviteMemberScreen> {
  final _email = TextEditingController();
  Role _role = Role.worker;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = l.invite_member_email_required);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).createInvitation(
            farmId: farmId,
            email: _email.text,
            role: _role,
            assignedAreaIds: const [],
            invitedBy: user.uid,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.invite_member_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l.invite_member_email_label),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'name@example.com'),
            ),
            SectionHeader(title: l.invite_member_role_label),
            // Owner role omitted intentionally: only one owner per farm;
            // ownership transfer is a separate flow.
            DropdownButtonFormField<Role>(
              initialValue: _role,
              decoration: const InputDecoration(),
              items: [
                DropdownMenuItem(
                  value: Role.manager,
                  child: Text(localizedRole(l, Role.manager)),
                ),
                DropdownMenuItem(
                  value: Role.worker,
                  child: Text(localizedRole(l, Role.worker)),
                ),
                DropdownMenuItem(
                  value: Role.vet,
                  child: Text(localizedRole(l, Role.vet)),
                ),
              ],
              onChanged: (v) => setState(() => _role = v ?? Role.worker),
            ),
            const SizedBox(height: 8),
            Text(
              l.invite_member_owner_omitted_note,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(l.invite_member_submit),
            ),
          ],
        ),
      ),
    );
  }
}
