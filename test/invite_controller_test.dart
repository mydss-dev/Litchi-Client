import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/invite_controller.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

void main() {
  InviteController build() =>
      InviteController(PanelApi(ApiClient()), () async {});

  test('applySnapshot builds a share link from code + urlBase', () {
    final c = build();
    c.applySnapshot(code: 'ABC', urlBase: 'https://example.com');
    expect(c.code, 'ABC');
    expect(c.link, 'https://example.com/#/register?code=ABC');
    expect(c.codes, hasLength(1));
    expect(c.codes.first.code, 'ABC');
  });

  test('applySnapshot honors a register-style base', () {
    final c = build();
    c.applySnapshot(code: 'XYZ', urlBase: 'https://example.com/register');
    expect(c.link, 'https://example.com/register?code=XYZ');
  });

  test('reset clears invite state', () {
    final c = build();
    c.applySnapshot(code: 'ABC', urlBase: 'https://example.com');
    c.reset();
    expect(c.code, isEmpty);
    expect(c.link, isEmpty);
    expect(c.codes, isEmpty);
  });
}
