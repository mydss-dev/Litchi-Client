// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle =>
      'Configure client preferences and network options';

  @override
  String get systemSettings => 'System';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get automaticUpdates => 'Automatic updates';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get connectionSettings => 'Connection';

  @override
  String get proxyMode => 'Proxy mode';

  @override
  String get connectionMethod => 'Connection method';

  @override
  String get systemProxy => 'System proxy';

  @override
  String get tunMode => 'TUN mode';

  @override
  String get systemProxyDescription =>
      'Route supported apps through the system proxy';

  @override
  String get tunDescription =>
      'Route all traffic through a virtual network adapter';

  @override
  String get advancedSettings => 'Advanced';

  @override
  String get connectionProtection => 'Connection interruption protection';

  @override
  String get systemProtectionDescription =>
      'Block direct access if the system proxy core exits';

  @override
  String get tunProtectionDescription =>
      'Block non-tunnel traffic if the TUN core exits';

  @override
  String get macTunProtectionUnavailable =>
      'Interruption protection is not yet available for macOS TUN';

  @override
  String get repairNetworkSettings => 'Repair network settings';

  @override
  String get repairNetworkDescription =>
      'Clear or reapply the system proxy when the network remains offline';

  @override
  String get repair => 'Repair';

  @override
  String get networkSettingsRepaired => 'Network settings repaired';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsDescription => 'View and copy information for support';

  @override
  String get view => 'View';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App version';

  @override
  String get coreVersion => 'Core version';

  @override
  String get loading => 'Loading…';

  @override
  String get networkSettings => 'Network settings';

  @override
  String get administratorRequired => 'Administrator privileges required';

  @override
  String get tunAdminHintWindows =>
      'TUN mode needs administrator privileges to create a virtual network adapter.\n\nRestart the client with “Run as administrator”, then enable TUN mode.';

  @override
  String get tunPermissionHintMac =>
      'Creating routes requires macOS system permission; connection fails safely if permission is denied.';

  @override
  String get gotIt => 'Got it';

  @override
  String get networkModeReconnect =>
      'Network mode changed. Reconnect to apply it.';

  @override
  String get switchingConnectionMethod => 'Switching connection method';

  @override
  String get home => 'Home';

  @override
  String get plans => 'Plans';

  @override
  String get invite => 'Invite';

  @override
  String get account => 'Account';

  @override
  String get nodes => 'Nodes';

  @override
  String get wallet => 'Wallet';

  @override
  String get walletSubtitle => 'Balance, commission and account top-up';

  @override
  String get orders => 'Orders';

  @override
  String get ordersSubtitle => 'View purchases and payment status';

  @override
  String get usage => 'Usage';

  @override
  String get usageSubtitle => 'View traffic and recent activity';

  @override
  String get support => 'Support';

  @override
  String get supportSubtitle => 'Contact customer support';

  @override
  String get settingsNavSubtitle => 'Network, proxy and appearance';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Enter your credentials to continue';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Start connecting to the world';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordSubtitle =>
      'Update your password to protect your account';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordSubtitle =>
      'We will send a verification code to your email';

  @override
  String get email => 'Email';

  @override
  String get emailOrUsernameHint => 'Enter email or username';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter password';

  @override
  String get rememberCredentials => 'Remember credentials';

  @override
  String get forgotPasswordAction => 'Forgot password?';

  @override
  String get login => 'Sign in';

  @override
  String get noAccount => 'No account yet?';

  @override
  String get registerAccount => 'Create account';

  @override
  String get requiredCredentials => 'Enter your email and password';

  @override
  String get loginSuccess => 'Welcome back!';

  @override
  String get or => 'or';
}
