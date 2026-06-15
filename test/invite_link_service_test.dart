import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/invite_link_service.dart';

void main() {
  test('keeps existing invite link from panel', () {
    expect(
      InviteLinkService.buildForCode(
        code: 'ABC123',
        existingLink: 'https://panel.example/register?code=ABC123',
        inviteUrlBase: 'https://fallback.example',
      ),
      'https://panel.example/register?code=ABC123',
    );
  });

  test('builds invite link from code template', () {
    expect(
      InviteLinkService.buildForCode(
        code: 'ABC123',
        existingLink: '',
        inviteUrlBase: 'https://site.example/invite/{code}/',
      ),
      'https://site.example/invite/ABC123',
    );
  });

  test('appends code to register routes', () {
    expect(
      InviteLinkService.buildForCode(
        code: 'ABC123',
        existingLink: '',
        inviteUrlBase: 'https://site.example/#/register',
      ),
      'https://site.example/#/register?code=ABC123',
    );
  });

  test('falls back to hash register route for site root', () {
    expect(
      InviteLinkService.buildForCode(
        code: 'ABC123',
        existingLink: '',
        inviteUrlBase: 'https://site.example/',
      ),
      'https://site.example/#/register?code=ABC123',
    );
  });

  test('normalizes single invite code into invite code list', () {
    final result = InviteLinkService.normalize(
      codes: const [],
      inviteCode: 'ABC123',
      inviteLink: '',
      inviteUrlBase: 'https://site.example',
    );

    expect(result.inviteCode, 'ABC123');
    expect(result.inviteLink, 'https://site.example/#/register?code=ABC123');
    expect(result.codes, hasLength(1));
    expect(result.codes.first.code, 'ABC123');
    expect(result.codes.first.link, result.inviteLink);
  });

  test('normalizes invite code list and selects first as primary invite', () {
    final result = InviteLinkService.normalize(
      codes: const [
        InviteCodeModel(code: 'FIRST', link: ''),
        InviteCodeModel(code: 'SECOND', link: 'https://panel.example/second'),
      ],
      inviteCode: '',
      inviteLink: '',
      inviteUrlBase: 'https://site.example/register',
    );

    expect(result.inviteCode, 'FIRST');
    expect(result.inviteLink, 'https://site.example/register?code=FIRST');
    expect(result.codes.first.link, result.inviteLink);
    expect(result.codes.last.link, 'https://panel.example/second');
  });
}
