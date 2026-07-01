import 'package:dio/dio.dart';

import '../../config/panel_backend.dart';

/// Handles the small transport differences between V2Board-compatible panels.
///
/// Domain endpoints stay canonical in [PanelApi]. This adapter only changes
/// encoding and known request-field aliases, so backend support does not fork
/// the whole API implementation.
class PanelBackendAdapter {
  const PanelBackendAdapter(this.type);

  final PanelType type;

  String? get postContentType =>
      type.usesFormPost ? Headers.formUrlEncodedContentType : null;

  Map<String, dynamic>? preparePostData(
    String path,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final result = Map<String, dynamic>.from(data);
    if (type == PanelType.xiaoV2board &&
        path == '/passport/comm/sendEmailVerify' &&
        result.containsKey('isForgetPassword')) {
      result['isforget'] = result.remove('isForgetPassword') == true ? 1 : 0;
    }
    return result;
  }
}
