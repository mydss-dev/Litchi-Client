import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/invite_data_state.dart';

void main() {
  test('defaults to an empty invite state', () {
    const state = InviteDataState();

    expect(state.codes, isEmpty);
    expect(state.code, isEmpty);
    expect(state.link, isEmpty);
    expect(state.urlBase, isEmpty);
  });

  test('copyWith updates provided fields and preserves omitted fields', () {
    const state = InviteDataState(
      code: 'ABC123',
      link: 'https://example.com/register?code=ABC123',
    );

    final updated = state.copyWith(
      codes: const [InviteCodeModel(code: 'XYZ', link: '')],
      urlBase: 'https://example.com',
    );

    expect(updated.code, 'ABC123');
    expect(updated.link, 'https://example.com/register?code=ABC123');
    expect(updated.codes.single.code, 'XYZ');
    expect(updated.urlBase, 'https://example.com');
  });
}
