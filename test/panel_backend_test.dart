import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/services/panel_backend_adapter.dart';

void main() {
  group('panel type', () {
    test('accepts supported config spellings', () {
      expect(PanelType.tryParse('v2board'), PanelType.v2board);
      expect(PanelType.tryParse('Xiao-V2board'), PanelType.xiaoV2board);
      expect(PanelType.tryParse('xiao_v2board'), PanelType.xiaoV2board);
      expect(PanelType.tryParse('XBOARD'), PanelType.xboard);
      expect(PanelType.tryParse('unknown'), isNull);
    });

    test('uses safe feature defaults and supports explicit overrides', () {
      final standard = PanelFeatures.defaultsFor(PanelType.v2board);
      final xiao = PanelFeatures.defaultsFor(PanelType.xiaoV2board);

      expect(standard.wallet, isFalse);
      expect(xiao.wallet, isTrue);
      expect(standard.onlineDevices, isFalse);
      expect(xiao.onlineDevices, isTrue);
      expect(
        standard.apply({'tickets': false, 'wallet': true}).tickets,
        isFalse,
      );
      expect(standard.apply({'tickets': false, 'wallet': true}).wallet, isTrue);
    });
  });

  group('panel backend adapter', () {
    test('V2Board keeps JSON post semantics', () {
      const adapter = PanelBackendAdapter(PanelType.v2board);
      expect(adapter.postContentType, isNull);
      expect(
        adapter.preparePostData('/passport/auth/login', {'email': 'a@b.c'}),
        {'email': 'a@b.c'},
      );
    });

    test('Xiao-V2Board uses form posts and aliases forget flag', () {
      const adapter = PanelBackendAdapter(PanelType.xiaoV2board);
      final data = adapter.preparePostData('/passport/comm/sendEmailVerify', {
        'email': 'a@b.c',
        'isForgetPassword': true,
      });

      expect(adapter.postContentType, 'application/x-www-form-urlencoded');
      expect(data, {'email': 'a@b.c', 'isforget': 1});
    });

    test('XBoard uses form posts without Xiao-only field aliases', () {
      const adapter = PanelBackendAdapter(PanelType.xboard);
      final data = adapter.preparePostData('/passport/comm/sendEmailVerify', {
        'isForgetPassword': true,
      });

      expect(adapter.postContentType, 'application/x-www-form-urlencoded');
      expect(data, {'isForgetPassword': true});
    });
  });

  test('remote config applies panel defaults and explicit capabilities', () {
    final oldType = AppConfig.panelType;
    final oldFeatures = AppConfig.panelFeatures;
    addTearDown(() {
      AppConfig.panelType = oldType;
      AppConfig.panelFeatures = oldFeatures;
    });

    AppConfig.applyRemote({
      'panel_type': 'xiao_v2board',
      'panel_features': {'traffic': false, 'tickets': false},
    });

    expect(AppConfig.panelType, PanelType.xiaoV2board);
    expect(AppConfig.panelFeatures.wallet, isTrue);
    expect(AppConfig.panelFeatures.traffic, isFalse);
    expect(AppConfig.panelFeatures.tickets, isFalse);
    expect(AppConfig.panelFeatures.onlineDevices, isTrue);
  });
}
