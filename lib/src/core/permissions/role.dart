import '../../l10n/generated/app_localizations.dart';

enum Role {
  owner('owner'),
  manager('manager'),
  worker('worker'),
  vet('vet');

  const Role(this.value);
  final String value;

  static Role fromString(String s) {
    return Role.values.firstWhere(
      (r) => r.value == s,
      orElse: () => Role.worker,
    );
  }
}

String localizedRole(AppLocalizations l, Role r) {
  switch (r) {
    case Role.owner:
      return l.team_role_owner;
    case Role.manager:
      return l.team_role_manager;
    case Role.worker:
      return l.team_role_worker;
    case Role.vet:
      return l.team_role_vet;
  }
}
