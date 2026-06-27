import '../../config/app_config.dart';
import '../models/app_models.dart';

abstract final class InviteLinkService {
  static String buildForCode({
    required String code,
    required String existingLink,
    required String inviteUrlBase,
    String? fallbackBase,
  }) {
    if (existingLink.isNotEmpty) return existingLink;
    if (code.isEmpty) return '';

    final configuredBase = _firstNotEmpty([
      inviteUrlBase,
      fallbackBase ?? AppConfig.inviteUrlBase,
    ]);
    if (configuredBase.isEmpty) return '';

    final base = configuredBase.replaceAll(RegExp(r'/+$'), '');
    if (base.contains('{code}')) return base.replaceAll('{code}', code);
    if (base.endsWith('/register') || base.endsWith('/#/register')) {
      return '$base?code=$code';
    }
    return '$base/#/register?code=$code';
  }

  static NormalizedInviteLinks normalize({
    required List<InviteCodeModel> codes,
    required String inviteCode,
    required String inviteLink,
    required String inviteUrlBase,
    String? fallbackBase,
  }) {
    var normalizedCode = inviteCode;
    var normalizedLink = inviteLink;
    var normalizedCodes = codes;

    if (normalizedCode.isNotEmpty) {
      normalizedLink = buildForCode(
        code: normalizedCode,
        existingLink: normalizedLink,
        inviteUrlBase: inviteUrlBase,
        fallbackBase: fallbackBase,
      );
    }

    if (normalizedCodes.isEmpty && normalizedCode.isNotEmpty) {
      normalizedCodes = [
        InviteCodeModel(
          code: normalizedCode,
          link: buildForCode(
            code: normalizedCode,
            existingLink: normalizedLink,
            inviteUrlBase: inviteUrlBase,
            fallbackBase: fallbackBase,
          ),
        ),
      ];
    } else if (normalizedCodes.isNotEmpty) {
      normalizedCodes = normalizedCodes
          .map(
            (item) => InviteCodeModel(
              code: item.code,
              link: buildForCode(
                code: item.code,
                existingLink: item.link,
                inviteUrlBase: inviteUrlBase,
                fallbackBase: fallbackBase,
              ),
            ),
          )
          .toList();
      normalizedCode = normalizedCodes.first.code;
      normalizedLink = normalizedCodes.first.link;
    }

    return NormalizedInviteLinks(
      codes: normalizedCodes,
      inviteCode: normalizedCode,
      inviteLink: normalizedLink,
    );
  }

  static String _firstNotEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}

class NormalizedInviteLinks {
  const NormalizedInviteLinks({
    required this.codes,
    required this.inviteCode,
    required this.inviteLink,
  });

  final List<InviteCodeModel> codes;
  final String inviteCode;
  final String inviteLink;
}
