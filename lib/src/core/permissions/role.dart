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
