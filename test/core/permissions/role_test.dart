import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Role.fromString returns the matching enum', () {
    expect(Role.fromString('owner'), Role.owner);
    expect(Role.fromString('manager'), Role.manager);
    expect(Role.fromString('worker'), Role.worker);
    expect(Role.fromString('vet'), Role.vet);
  });

  test('Role.fromString defaults to worker for unknown', () {
    expect(Role.fromString('asdf'), Role.worker);
  });

  test('Role.value returns the wire string', () {
    expect(Role.owner.value, 'owner');
    expect(Role.vet.value, 'vet');
  });
}
