import 'app_models.dart';

class InviteDataState {
  const InviteDataState({
    this.codes = const [],
    this.code = '',
    this.link = '',
    this.urlBase = '',
  });

  final List<InviteCodeModel> codes;
  final String code;
  final String link;
  final String urlBase;

  InviteDataState copyWith({
    List<InviteCodeModel>? codes,
    String? code,
    String? link,
    String? urlBase,
  }) {
    return InviteDataState(
      codes: codes ?? this.codes,
      code: code ?? this.code,
      link: link ?? this.link,
      urlBase: urlBase ?? this.urlBase,
    );
  }
}
