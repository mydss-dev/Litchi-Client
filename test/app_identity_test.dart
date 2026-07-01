import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_identity.dart';

void main() {
  test('keeps the default client compatible with the legacy identity', () {
    expect(AppIdentity.storageKeyFor('litchi'), 'litchi');
    expect(AppIdentity.instanceLockPortFor('litchi'), 54891);
  });

  test('normalizes tenant ids for filesystem and registry use', () {
    expect(
      AppIdentity.storageKeyFor(' Client 6197401242 / Demo '),
      'client-6197401242-demo',
    );
    expect(
      AppIdentity.storageDirectoryNameFor('tenant-a'),
      isNot(contains('Litchi')),
    );
    expect(
      AppIdentity.autoStartValueNameFor('tenant-a'),
      isNot(contains('Litchi')),
    );
    expect(AppIdentity.tunInterfaceAliasFor('tenant-a'), 'TUN-A');
    expect(
      AppIdentity.tunInterfaceAliasFor('tenant_8f3a91c2d46e7788'),
      'TUN-8F3A91C2D46E',
    );
  });

  test('gives different tenants stable private lock ports', () {
    final first = AppIdentity.instanceLockPortFor('tenant-a');
    final second = AppIdentity.instanceLockPortFor('tenant-b');

    expect(first, inInclusiveRange(49152, 65534));
    expect(second, inInclusiveRange(49152, 65534));
    expect(first, isNot(second));
    expect(AppIdentity.instanceLockPortFor('tenant-a'), first);
  });

  test('keeps legacy preference keys only for the default client', () {
    expect(AppIdentity.preferenceKeyFor('litchi', 'language'), 'language');
    expect(
      AppIdentity.preferenceKeyFor('tenant-a', 'language'),
      'tenant-a:language',
    );
  });
}
