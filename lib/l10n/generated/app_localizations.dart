import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure client preferences and network options'**
  String get settingsSubtitle;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemSettings;

  /// No description provided for @launchAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartup;

  /// No description provided for @silentStartup.
  ///
  /// In en, this message translates to:
  /// **'Start silently'**
  String get silentStartup;

  /// No description provided for @automaticUpdates.
  ///
  /// In en, this message translates to:
  /// **'Automatic updates'**
  String get automaticUpdates;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language settings'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @traditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get traditionalChinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSettings;

  /// No description provided for @proxyMode.
  ///
  /// In en, this message translates to:
  /// **'Proxy mode'**
  String get proxyMode;

  /// No description provided for @connectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Connection method'**
  String get connectionMethod;

  /// No description provided for @systemProxy.
  ///
  /// In en, this message translates to:
  /// **'System proxy'**
  String get systemProxy;

  /// No description provided for @tunMode.
  ///
  /// In en, this message translates to:
  /// **'TUN mode'**
  String get tunMode;

  /// No description provided for @dns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dns;

  /// No description provided for @systemProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'Route supported apps through the system proxy'**
  String get systemProxyDescription;

  /// No description provided for @tunDescription.
  ///
  /// In en, this message translates to:
  /// **'Route all traffic through a virtual network adapter'**
  String get tunDescription;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @connectionProtection.
  ///
  /// In en, this message translates to:
  /// **'Connection protection'**
  String get connectionProtection;

  /// No description provided for @systemProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Block direct access if the system proxy core exits'**
  String get systemProtectionDescription;

  /// No description provided for @tunProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Block non-tunnel traffic if the TUN core exits'**
  String get tunProtectionDescription;

  /// No description provided for @macTunProtectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Interruption protection is not yet available for macOS TUN'**
  String get macTunProtectionUnavailable;

  /// No description provided for @repairNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Repair network'**
  String get repairNetworkSettings;

  /// No description provided for @repairNetworkDescription.
  ///
  /// In en, this message translates to:
  /// **'Clear or reapply the system proxy when the network remains offline'**
  String get repairNetworkDescription;

  /// No description provided for @repair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get repair;

  /// No description provided for @networkSettingsRepaired.
  ///
  /// In en, this message translates to:
  /// **'Network settings repaired'**
  String get networkSettingsRepaired;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'View and copy information for support'**
  String get diagnosticsDescription;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @coreVersion.
  ///
  /// In en, this message translates to:
  /// **'Core version'**
  String get coreVersion;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network settings'**
  String get networkSettings;

  /// No description provided for @administratorRequired.
  ///
  /// In en, this message translates to:
  /// **'Administrator privileges required'**
  String get administratorRequired;

  /// No description provided for @tunAdminHintWindows.
  ///
  /// In en, this message translates to:
  /// **'TUN mode needs administrator privileges to create a virtual network adapter.\n\nRestart the client with “Run as administrator”, then enable TUN mode.'**
  String get tunAdminHintWindows;

  /// No description provided for @tunPermissionHintMac.
  ///
  /// In en, this message translates to:
  /// **'Creating routes requires macOS system permission; connection fails safely if permission is denied.'**
  String get tunPermissionHintMac;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @networkModeReconnect.
  ///
  /// In en, this message translates to:
  /// **'Network mode changed. Reconnect to apply it.'**
  String get networkModeReconnect;

  /// No description provided for @switchingConnectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Switching connection method'**
  String get switchingConnectionMethod;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plans;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @nodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get nodes;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @walletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balance, commission and account top-up'**
  String get walletSubtitle;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @ordersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View purchases and payment status'**
  String get ordersSubtitle;

  /// No description provided for @usage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// No description provided for @usageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View traffic and recent activity'**
  String get usageSubtitle;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @supportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contact customer support'**
  String get supportSubtitle;

  /// No description provided for @settingsNavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network, proxy and appearance'**
  String get settingsNavSubtitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to continue'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start connecting to the world'**
  String get registerSubtitle;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your password to protect your account'**
  String get changePasswordSubtitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will send a verification code to your email'**
  String get forgotPasswordSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailOrUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email or username'**
  String get emailOrUsernameHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get passwordHint;

  /// No description provided for @rememberCredentials.
  ///
  /// In en, this message translates to:
  /// **'Remember credentials'**
  String get rememberCredentials;

  /// No description provided for @forgotPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordAction;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get login;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get noAccount;

  /// No description provided for @registerAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerAccount;

  /// No description provided for @requiredCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password'**
  String get requiredCredentials;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get loginSuccess;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @fillEmailPrefix.
  ///
  /// In en, this message translates to:
  /// **'Enter the email prefix first'**
  String get fillEmailPrefix;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent. Check your email.'**
  String get verificationCodeSent;

  /// No description provided for @passwordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get passwordsMismatch;

  /// No description provided for @verificationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the email verification code'**
  String get verificationCodeRequired;

  /// No description provided for @acceptTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms of Service first'**
  String get acceptTermsRequired;

  /// No description provided for @registrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}!'**
  String registrationSuccess(String appName);

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @verificationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the email verification code'**
  String get verificationCodeHint;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the password again'**
  String get confirmPasswordHint;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Invite code (optional)'**
  String get inviteCodeOptional;

  /// No description provided for @termsAgreementPrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to '**
  String get termsAgreementPrefix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendVerificationCode;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend ({seconds}s)'**
  String resendIn(int seconds);

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @allFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete all fields'**
  String get allFieldsRequired;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Sign in again.'**
  String get passwordResetSuccess;

  /// No description provided for @registeredEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email'**
  String get registeredEmailHint;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get newPasswordHint;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// No description provided for @passwordFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete all password fields'**
  String get passwordFieldsRequired;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @currentPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get currentPasswordHint;

  /// No description provided for @passwordAdvice.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters with letters and numbers'**
  String get passwordAdvice;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshed;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionSuccess;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View connection, node and traffic status'**
  String get dashboardSubtitle;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @asia.
  ///
  /// In en, this message translates to:
  /// **'Asia'**
  String get asia;

  /// No description provided for @europe.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get europe;

  /// No description provided for @america.
  ///
  /// In en, this message translates to:
  /// **'Americas'**
  String get america;

  /// No description provided for @oceania.
  ///
  /// In en, this message translates to:
  /// **'Oceania'**
  String get oceania;

  /// No description provided for @nodesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a fast route'**
  String get nodesSubtitle;

  /// No description provided for @selectLineAndLatency.
  ///
  /// In en, this message translates to:
  /// **'Choose a route and view latency'**
  String get selectLineAndLatency;

  /// No description provided for @noMatchingNodes.
  ///
  /// In en, this message translates to:
  /// **'No matching nodes'**
  String get noMatchingNodes;

  /// No description provided for @tryDifferentNodeFilter.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or region'**
  String get tryDifferentNodeFilter;

  /// No description provided for @searchNodes.
  ///
  /// In en, this message translates to:
  /// **'Search nodes'**
  String get searchNodes;

  /// No description provided for @autoSelect.
  ///
  /// In en, this message translates to:
  /// **'Auto select'**
  String get autoSelect;

  /// No description provided for @manualSelect.
  ///
  /// In en, this message translates to:
  /// **'Manual select'**
  String get manualSelect;

  /// No description provided for @autoSelectBestDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically use the lowest-latency route'**
  String get autoSelectBestDescription;

  /// No description provided for @autoSelectEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto select enabled. The best node will be used.'**
  String get autoSelectEnabled;

  /// No description provided for @switchedToNode.
  ///
  /// In en, this message translates to:
  /// **'Switched to {node}'**
  String switchedToNode(String node);

  /// No description provided for @noTestableNodes.
  ///
  /// In en, this message translates to:
  /// **'No nodes available for testing'**
  String get noTestableNodes;

  /// No description provided for @latencyTestComplete.
  ///
  /// In en, this message translates to:
  /// **'Latency test completed'**
  String get latencyTestComplete;

  /// No description provided for @latencyTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Latency test failed. Check the nodes and try again.'**
  String get latencyTestFailed;

  /// No description provided for @latencyTest.
  ///
  /// In en, this message translates to:
  /// **'Test latency'**
  String get latencyTest;

  /// No description provided for @noNodes.
  ///
  /// In en, this message translates to:
  /// **'No nodes'**
  String get noNodes;

  /// No description provided for @waitForSubscription.
  ///
  /// In en, this message translates to:
  /// **'If you just signed in, wait for subscription data to load'**
  String get waitForSubscription;

  /// No description provided for @chooseNode.
  ///
  /// In en, this message translates to:
  /// **'Choose node'**
  String get chooseNode;

  /// No description provided for @nodeCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} nodes · Filter routes and view latency'**
  String nodeCountSummary(int count);

  /// No description provided for @noNodesSubscription.
  ///
  /// In en, this message translates to:
  /// **'No nodes · Check subscription status'**
  String get noNodesSubscription;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @currentNode.
  ///
  /// In en, this message translates to:
  /// **'Current node'**
  String get currentNode;

  /// No description provided for @nodeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading nodes'**
  String get nodeLoading;

  /// No description provided for @nodeStatus.
  ///
  /// In en, this message translates to:
  /// **'Node status'**
  String get nodeStatus;

  /// No description provided for @fetchingNodes.
  ///
  /// In en, this message translates to:
  /// **'Fetching nodes...'**
  String get fetchingNodes;

  /// No description provided for @noAvailableNodes.
  ///
  /// In en, this message translates to:
  /// **'No available nodes'**
  String get noAvailableNodes;

  /// No description provided for @syncingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Syncing subscription data...'**
  String get syncingSubscription;

  /// No description provided for @subscriptionLoadsAfterLogin.
  ///
  /// In en, this message translates to:
  /// **'Subscription nodes load automatically after sign-in'**
  String get subscriptionLoadsAfterLogin;

  /// No description provided for @encryptionProtectionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Encrypted protection is active'**
  String get encryptionProtectionEnabled;

  /// No description provided for @establishingEncryptedChannel.
  ///
  /// In en, this message translates to:
  /// **'Establishing encrypted channel...'**
  String get establishingEncryptedChannel;

  /// No description provided for @closingEncryptedChannel.
  ///
  /// In en, this message translates to:
  /// **'Closing encrypted channel...'**
  String get closingEncryptedChannel;

  /// No description provided for @networkNotProtected.
  ///
  /// In en, this message translates to:
  /// **'Network traffic is not currently protected'**
  String get networkNotProtected;

  /// No description provided for @nodeMode.
  ///
  /// In en, this message translates to:
  /// **'Node mode · {mode}'**
  String nodeMode(String mode);

  /// No description provided for @switchNode.
  ///
  /// In en, this message translates to:
  /// **'Switch node'**
  String get switchNode;

  /// No description provided for @viewNodes.
  ///
  /// In en, this message translates to:
  /// **'View nodes'**
  String get viewNodes;

  /// No description provided for @startConnection.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get startConnection;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @disconnectConnection.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectConnection;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get disconnecting;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @proxyModeDescriptionRule.
  ///
  /// In en, this message translates to:
  /// **'Route local traffic directly and other traffic through the proxy'**
  String get proxyModeDescriptionRule;

  /// No description provided for @proxyModeDescriptionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Route all traffic through the proxy node'**
  String get proxyModeDescriptionGlobal;

  /// No description provided for @proxyModeDescriptionDirect.
  ///
  /// In en, this message translates to:
  /// **'Connect directly without using the proxy'**
  String get proxyModeDescriptionDirect;

  /// No description provided for @switchedProxyMode.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode}'**
  String switchedProxyMode(String mode);

  /// No description provided for @proxyModeNextConnection.
  ///
  /// In en, this message translates to:
  /// **'The proxy mode applies on the next connection'**
  String get proxyModeNextConnection;

  /// No description provided for @ruleMode.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get ruleMode;

  /// No description provided for @globalMode.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalMode;

  /// No description provided for @directMode.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get directMode;

  /// No description provided for @currentLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get currentLatency;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadSpeed;

  /// No description provided for @uploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadSpeed;

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Subscription expired. Connection is unavailable.'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Subscription expires today. Renew now.'**
  String get subscriptionExpiresToday;

  /// No description provided for @subscriptionExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Subscription expires in {days} days'**
  String subscriptionExpiresInDays(int days);

  /// No description provided for @renewNow.
  ///
  /// In en, this message translates to:
  /// **'Renew →'**
  String get renewNow;

  /// No description provided for @renewPlan.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get renewPlan;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @businessEdition.
  ///
  /// In en, this message translates to:
  /// **'Business edition'**
  String get businessEdition;

  /// No description provided for @protected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get protected;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @androidLimitedNotice.
  ///
  /// In en, this message translates to:
  /// **'This Android version currently supports sign-in, purchases and node viewing'**
  String get androidLimitedNotice;

  /// No description provided for @syncingNodes.
  ///
  /// In en, this message translates to:
  /// **'Syncing nodes...'**
  String get syncingNodes;

  /// No description provided for @selectNodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a node'**
  String get selectNodePrompt;

  /// No description provided for @nodeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Node mode: {mode}'**
  String nodeModeLabel(String mode);

  /// No description provided for @buyPlans.
  ///
  /// In en, this message translates to:
  /// **'Buy plans'**
  String get buyPlans;

  /// No description provided for @buyPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan or data pack'**
  String get buyPlansSubtitle;

  /// No description provided for @planPurchase.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get planPurchase;

  /// No description provided for @recurringPlan.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringPlan;

  /// No description provided for @oneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get oneTime;

  /// No description provided for @dataPack.
  ///
  /// In en, this message translates to:
  /// **'Data pack'**
  String get dataPack;

  /// No description provided for @noPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans available'**
  String get noPlans;

  /// No description provided for @refreshLater.
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again later'**
  String get refreshLater;

  /// No description provided for @unlimitedTime.
  ///
  /// In en, this message translates to:
  /// **'/ No expiry'**
  String get unlimitedTime;

  /// No description provided for @oneTimePlan.
  ///
  /// In en, this message translates to:
  /// **'One-time plan'**
  String get oneTimePlan;

  /// No description provided for @devicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String devicesCount(int count);

  /// No description provided for @unlimitedDevices.
  ///
  /// In en, this message translates to:
  /// **'Unlimited devices'**
  String get unlimitedDevices;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// No description provided for @unavailableForPurchase.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailableForPurchase;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @quarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get quarterly;

  /// No description provided for @halfYear.
  ///
  /// In en, this message translates to:
  /// **'Half-year'**
  String get halfYear;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get perMonth;

  /// No description provided for @perQuarter.
  ///
  /// In en, this message translates to:
  /// **'/ quarter'**
  String get perQuarter;

  /// No description provided for @perHalfYear.
  ///
  /// In en, this message translates to:
  /// **'/ half-year'**
  String get perHalfYear;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/ year'**
  String get perYear;

  /// No description provided for @orderHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View purchases and payments'**
  String get orderHistorySubtitle;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @orderLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders'**
  String get orderLoadFailed;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders'**
  String get noOrders;

  /// No description provided for @ordersAppearAfterPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchased plans will appear here'**
  String get ordersAppearAfterPurchase;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderCancelled;

  /// No description provided for @accountTopUp.
  ///
  /// In en, this message translates to:
  /// **'Account top-up'**
  String get accountTopUp;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String orderNumber(String number);

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @continuePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue payment'**
  String get continuePayment;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @cancelOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this unpaid order? You will need to place it again.'**
  String get cancelOrderConfirm;

  /// No description provided for @thinkAgain.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get thinkAgain;

  /// No description provided for @confirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get confirmCancel;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @inviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your invite link and view commission records'**
  String get inviteSubtitle;

  /// No description provided for @inviteCommission.
  ///
  /// In en, this message translates to:
  /// **'Referral commission'**
  String get inviteCommission;

  /// No description provided for @inviteCodeCreated.
  ///
  /// In en, this message translates to:
  /// **'Invite code created'**
  String get inviteCodeCreated;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get creating;

  /// No description provided for @createInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get createInviteCode;

  /// No description provided for @inviteCodeIndex.
  ///
  /// In en, this message translates to:
  /// **'Invite code {index}'**
  String inviteCodeIndex(int index);

  /// No description provided for @inviteLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invite link is not configured'**
  String get inviteLinkUnavailable;

  /// No description provided for @registeredUsers.
  ///
  /// In en, this message translates to:
  /// **'Registered users'**
  String get registeredUsers;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} users'**
  String peopleCount(int count);

  /// No description provided for @pendingCommission.
  ///
  /// In en, this message translates to:
  /// **'Pending commission'**
  String get pendingCommission;

  /// No description provided for @totalCommission.
  ///
  /// In en, this message translates to:
  /// **'Total commission'**
  String get totalCommission;

  /// No description provided for @commissionRate.
  ///
  /// In en, this message translates to:
  /// **'Commission rate'**
  String get commissionRate;

  /// No description provided for @commissionRecords.
  ///
  /// In en, this message translates to:
  /// **'Commission records'**
  String get commissionRecords;

  /// No description provided for @noCommissionRecords.
  ///
  /// In en, this message translates to:
  /// **'No commission records'**
  String get noCommissionRecords;

  /// No description provided for @invitedUser.
  ///
  /// In en, this message translates to:
  /// **'Invited user'**
  String get invitedUser;

  /// No description provided for @recordOrderAmount.
  ///
  /// In en, this message translates to:
  /// **'{date} · Order {amount}'**
  String recordOrderAmount(String date, String amount);

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @linkCopiedForApp.
  ///
  /// In en, this message translates to:
  /// **'Link copied. Paste it into {app}'**
  String linkCopiedForApp(String app);

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get confirmOrder;

  /// No description provided for @selectBillingCycle.
  ///
  /// In en, this message translates to:
  /// **'Select billing cycle'**
  String get selectBillingCycle;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponCode;

  /// No description provided for @couponHint.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code (optional)'**
  String get couponHint;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifying;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied'**
  String get couponApplied;

  /// No description provided for @invalidCoupon.
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon'**
  String get invalidCoupon;

  /// No description provided for @discountAmount.
  ///
  /// In en, this message translates to:
  /// **'Discount {amount}'**
  String discountAmount(String amount);

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String discountPercent(int percent);

  /// No description provided for @originalPrice.
  ///
  /// In en, this message translates to:
  /// **'Original price'**
  String get originalPrice;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get totalDue;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @submitOrder.
  ///
  /// In en, this message translates to:
  /// **'Submit order'**
  String get submitOrder;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'{operation} failed: {error}'**
  String operationFailed(String operation, String error);

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get selectPaymentMethod;

  /// No description provided for @browserPayment.
  ///
  /// In en, this message translates to:
  /// **'Browser payment'**
  String get browserPayment;

  /// No description provided for @scanToPay.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay'**
  String get scanToPay;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paymentSuccess;

  /// No description provided for @paymentTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Payment timed out'**
  String get paymentTimedOut;

  /// No description provided for @qrExpired.
  ///
  /// In en, this message translates to:
  /// **'QR code expired'**
  String get qrExpired;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get amountDue;

  /// No description provided for @balanceApplied.
  ///
  /// In en, this message translates to:
  /// **'Balance applied'**
  String get balanceApplied;

  /// No description provided for @subscriptionCredit.
  ///
  /// In en, this message translates to:
  /// **'Old subscription credit'**
  String get subscriptionCredit;

  /// No description provided for @refundAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund amount'**
  String get refundAmountLabel;

  /// No description provided for @paymentHandlingFee.
  ///
  /// In en, this message translates to:
  /// **'Payment handling fee'**
  String get paymentHandlingFee;

  /// No description provided for @paymentFeeDescription.
  ///
  /// In en, this message translates to:
  /// **'Fee: {value}'**
  String paymentFeeDescription(String value);

  /// No description provided for @balancePayment.
  ///
  /// In en, this message translates to:
  /// **'Balance payment'**
  String get balancePayment;

  /// No description provided for @activateWithBalance.
  ///
  /// In en, this message translates to:
  /// **'Activate with balance'**
  String get activateWithBalance;

  /// No description provided for @choosePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment method'**
  String get choosePaymentMethod;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods available'**
  String get noPaymentMethods;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @scanWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Scan with your phone to complete payment'**
  String get scanWithPhone;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'or open in a browser'**
  String get openInBrowser;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'{time} remaining'**
  String remainingTime(String time);

  /// No description provided for @paymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'I have completed payment'**
  String get paymentCompleted;

  /// No description provided for @paymentNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Payment not detected. Try again shortly.'**
  String get paymentNotDetected;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payment is being processed. The status will update automatically.'**
  String get paymentProcessing;

  /// No description provided for @orderActivated.
  ///
  /// In en, this message translates to:
  /// **'The order is active. Refresh to view it.'**
  String get orderActivated;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @refreshQrCode.
  ///
  /// In en, this message translates to:
  /// **'Refresh QR code'**
  String get refreshQrCode;

  /// No description provided for @getPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Get payment methods'**
  String get getPaymentMethods;

  /// No description provided for @startPayment.
  ///
  /// In en, this message translates to:
  /// **'Start payment'**
  String get startPayment;

  /// No description provided for @queryPayment.
  ///
  /// In en, this message translates to:
  /// **'Check payment'**
  String get queryPayment;

  /// No description provided for @refreshPayment.
  ///
  /// In en, this message translates to:
  /// **'Refresh payment'**
  String get refreshPayment;

  /// No description provided for @orderPending.
  ///
  /// In en, this message translates to:
  /// **'Pending payment'**
  String get orderPending;

  /// No description provided for @orderProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderProcessing;

  /// No description provided for @orderCancelledStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderCancelledStatus;

  /// No description provided for @orderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderCompleted;

  /// No description provided for @orderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get orderFailed;

  /// No description provided for @twoYears.
  ///
  /// In en, this message translates to:
  /// **'Two years'**
  String get twoYears;

  /// No description provided for @threeYears.
  ///
  /// In en, this message translates to:
  /// **'Three years'**
  String get threeYears;

  /// No description provided for @perTwoYears.
  ///
  /// In en, this message translates to:
  /// **'/ 2 years'**
  String get perTwoYears;

  /// No description provided for @perThreeYears.
  ///
  /// In en, this message translates to:
  /// **'/ 3 years'**
  String get perThreeYears;

  /// No description provided for @orderDiscounted.
  ///
  /// In en, this message translates to:
  /// **'Discounted'**
  String get orderDiscounted;

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// No description provided for @lowStockRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String lowStockRemaining(int count);

  /// No description provided for @existingPlanSwitchWarning.
  ///
  /// In en, this message translates to:
  /// **'Your active plan is {current}. Purchasing {target} may replace or offset the current subscription.'**
  String existingPlanSwitchWarning(String current, String target);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @buyout.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get buyout;

  /// No description provided for @wechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get wechat;

  /// No description provided for @connectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Connection in progress'**
  String get connectionInProgress;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @diagnosticPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform: {platform}'**
  String diagnosticPlatform(String platform);

  /// No description provided for @diagnosticConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status: {status}'**
  String diagnosticConnectionStatus(String status);

  /// No description provided for @diagnosticProxyPort.
  ///
  /// In en, this message translates to:
  /// **'Local proxy port: {port}'**
  String diagnosticProxyPort(int port);

  /// No description provided for @diagnosticRecordedAt.
  ///
  /// In en, this message translates to:
  /// **'Recorded at: {time}'**
  String diagnosticRecordedAt(String time);

  /// No description provided for @diagnosticRecentError.
  ///
  /// In en, this message translates to:
  /// **'Recent error: {error}'**
  String diagnosticRecentError(String error);

  /// No description provided for @noRuntimeLogs.
  ///
  /// In en, this message translates to:
  /// **'No runtime logs yet. Try connecting first.'**
  String get noRuntimeLogs;

  /// No description provided for @systemDns.
  ///
  /// In en, this message translates to:
  /// **'System DNS'**
  String get systemDns;

  /// No description provided for @cloudflareDns.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare DNS'**
  String get cloudflareDns;

  /// No description provided for @googleDns.
  ///
  /// In en, this message translates to:
  /// **'Google DNS'**
  String get googleDns;

  /// No description provided for @httpSecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'The current server uses HTTP. Data is not encrypted and may be intercepted. Ask the provider to enable HTTPS.'**
  String get httpSecurityWarning;

  /// No description provided for @diagnosticCopyDescription.
  ///
  /// In en, this message translates to:
  /// **'Copy and send this to support to help diagnose the issue'**
  String get diagnosticCopyDescription;

  /// No description provided for @diagnosticCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied. Send them to support.'**
  String get diagnosticCopied;

  /// No description provided for @copyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get copyDiagnostics;

  /// No description provided for @restartClientError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Restart the client and try again.'**
  String get restartClientError;

  /// No description provided for @proxyPortUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'The local proxy port did not start. Close other proxy apps and try again.'**
  String get proxyPortUnavailableError;

  /// No description provided for @missingCoreError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. The sing-box core is missing.'**
  String get missingCoreError;

  /// No description provided for @permissionDeniedError.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Run the client as administrator.'**
  String get permissionDeniedError;

  /// No description provided for @tunInterfaceUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'TUN adapter failed to start. Check system permission and try again.'**
  String get tunInterfaceUnavailableError;

  /// No description provided for @tunKillSwitchUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'TUN interruption protection failed. Connection was stopped to prevent leaks.'**
  String get tunKillSwitchUnavailableError;

  /// No description provided for @androidStartFailedError.
  ///
  /// In en, this message translates to:
  /// **'Android core failed to start'**
  String get androidStartFailedError;

  /// No description provided for @unexpectedCoreExitError.
  ///
  /// In en, this message translates to:
  /// **'The core exited unexpectedly. Reconnect to continue.'**
  String get unexpectedCoreExitError;

  /// No description provided for @invalidNodeConfigError.
  ///
  /// In en, this message translates to:
  /// **'The selected node is invalid. Choose another node.'**
  String get invalidNodeConfigError;

  /// No description provided for @genericConnectionFailureError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Change nodes or try again later.'**
  String get genericConnectionFailureError;

  /// No description provided for @configBuildFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate configuration. Choose another node.'**
  String get configBuildFailedError;

  /// No description provided for @cachedModeActive.
  ///
  /// In en, this message translates to:
  /// **'Server connection failed. Cached mode is active and saved nodes remain available.'**
  String get cachedModeActive;

  /// No description provided for @serverUnavailableNoCache.
  ///
  /// In en, this message translates to:
  /// **'The server is unavailable and no nodes are cached. Check the network or contact support.'**
  String get serverUnavailableNoCache;

  /// No description provided for @trafficStatistics.
  ///
  /// In en, this message translates to:
  /// **'Traffic statistics'**
  String get trafficStatistics;

  /// No description provided for @trafficStatisticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View traffic, devices and plan cycle'**
  String get trafficStatisticsSubtitle;

  /// No description provided for @remainingTraffic.
  ///
  /// In en, this message translates to:
  /// **'{value} GB remaining'**
  String remainingTraffic(String value);

  /// No description provided for @onlineDevices.
  ///
  /// In en, this message translates to:
  /// **'Online devices'**
  String get onlineDevices;

  /// No description provided for @currentOnlineDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices currently online'**
  String get currentOnlineDevices;

  /// No description provided for @remainingDays.
  ///
  /// In en, this message translates to:
  /// **'Days remaining'**
  String get remainingDays;

  /// No description provided for @permanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get permanent;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysUnit;

  /// No description provided for @subscriptionLongTerm.
  ///
  /// In en, this message translates to:
  /// **'Subscription does not expire'**
  String get subscriptionLongTerm;

  /// No description provided for @expiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresAt(String date);

  /// No description provided for @trafficResetTime.
  ///
  /// In en, this message translates to:
  /// **'Traffic reset'**
  String get trafficResetTime;

  /// No description provided for @neverResets.
  ///
  /// In en, this message translates to:
  /// **'Never resets'**
  String get neverResets;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @noTrafficReset.
  ///
  /// In en, this message translates to:
  /// **'This plan has no traffic reset cycle'**
  String get noTrafficReset;

  /// No description provided for @untilNextReset.
  ///
  /// In en, this message translates to:
  /// **'Until next reset'**
  String get untilNextReset;

  /// No description provided for @trafficTrend.
  ///
  /// In en, this message translates to:
  /// **'Traffic trend'**
  String get trafficTrend;

  /// No description provided for @periodTrafficTotal.
  ///
  /// In en, this message translates to:
  /// **'{period} · {total} total'**
  String periodTrafficTotal(String period, String total);

  /// No description provided for @recentDays.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String recentDays(int count);

  /// No description provided for @tooltipUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload {value}'**
  String tooltipUpload(String value);

  /// No description provided for @tooltipDownload.
  ///
  /// In en, this message translates to:
  /// **'Download {value}'**
  String tooltipDownload(String value);

  /// No description provided for @tooltipTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {value}'**
  String tooltipTotal(String value);

  /// No description provided for @weekdayShort.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get weekdayShort;

  /// No description provided for @ticketSupport.
  ///
  /// In en, this message translates to:
  /// **'Ticket support'**
  String get ticketSupport;

  /// No description provided for @ticketSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit an issue and view replies'**
  String get ticketSupportSubtitle;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @ticketSupportCompactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit issues and view support replies'**
  String get ticketSupportCompactSubtitle;

  /// No description provided for @newTicket.
  ///
  /// In en, this message translates to:
  /// **'New ticket'**
  String get newTicket;

  /// No description provided for @ticketLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tickets'**
  String get ticketLoadFailed;

  /// No description provided for @noTickets.
  ///
  /// In en, this message translates to:
  /// **'No tickets'**
  String get noTickets;

  /// No description provided for @noTicketsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a ticket to contact support'**
  String get noTicketsSubtitle;

  /// No description provided for @untitledTicket.
  ///
  /// In en, this message translates to:
  /// **'Untitled ticket'**
  String get untitledTicket;

  /// No description provided for @ticketFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject and issue description'**
  String get ticketFieldsRequired;

  /// No description provided for @ticketSubjectTooShort.
  ///
  /// In en, this message translates to:
  /// **'The subject must be at least 5 characters'**
  String get ticketSubjectTooShort;

  /// No description provided for @ticketMessageTooShort.
  ///
  /// In en, this message translates to:
  /// **'The description must be at least 10 characters'**
  String get ticketMessageTooShort;

  /// No description provided for @ticketSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Ticket submitted'**
  String get ticketSubmitted;

  /// No description provided for @ticketSubscriptionMismatch.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active, but the ticket service has not synchronized its status. Try again later or contact the administrator.'**
  String get ticketSubscriptionMismatch;

  /// No description provided for @issueSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get issueSubject;

  /// No description provided for @issueSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in one sentence'**
  String get issueSubjectHint;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @issueDescription.
  ///
  /// In en, this message translates to:
  /// **'Issue description'**
  String get issueDescription;

  /// No description provided for @issueDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in detail'**
  String get issueDescriptionHint;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit ticket'**
  String get submitTicket;

  /// No description provided for @replyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a reply'**
  String get replyRequired;

  /// No description provided for @replySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get replySent;

  /// No description provided for @ticketClosed.
  ///
  /// In en, this message translates to:
  /// **'Ticket closed'**
  String get ticketClosed;

  /// No description provided for @ticketDetails.
  ///
  /// In en, this message translates to:
  /// **'Ticket details'**
  String get ticketDetails;

  /// No description provided for @replyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your reply'**
  String get replyHint;

  /// No description provided for @closing.
  ///
  /// In en, this message translates to:
  /// **'Closing...'**
  String get closing;

  /// No description provided for @closeTicket.
  ///
  /// In en, this message translates to:
  /// **'Close ticket'**
  String get closeTicket;

  /// No description provided for @sendReply.
  ///
  /// In en, this message translates to:
  /// **'Send reply'**
  String get sendReply;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @noTicketMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noTicketMessages;

  /// No description provided for @customerSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get customerSupport;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @ticketClosedStatus.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get ticketClosedStatus;

  /// No description provided for @invalidRechargeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid recharge amount'**
  String get invalidRechargeAmount;

  /// No description provided for @noTransferableCommission.
  ///
  /// In en, this message translates to:
  /// **'No commission available to transfer'**
  String get noTransferableCommission;

  /// No description provided for @withdrawalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals are currently unavailable'**
  String get withdrawalUnavailable;

  /// No description provided for @noWithdrawableCommission.
  ///
  /// In en, this message translates to:
  /// **'No commission available to withdraw'**
  String get noWithdrawableCommission;

  /// No description provided for @noWithdrawalMethods.
  ///
  /// In en, this message translates to:
  /// **'No withdrawal methods are available'**
  String get noWithdrawalMethods;

  /// No description provided for @myWallet.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get myWallet;

  /// No description provided for @myWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View balance, commission and recharge'**
  String get myWalletSubtitle;

  /// No description provided for @accountAssets.
  ///
  /// In en, this message translates to:
  /// **'Account assets'**
  String get accountAssets;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account balance'**
  String get accountBalance;

  /// No description provided for @withdrawableCommission.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable commission'**
  String get withdrawableCommission;

  /// No description provided for @transferCommission.
  ///
  /// In en, this message translates to:
  /// **'Transfer commission'**
  String get transferCommission;

  /// No description provided for @transferShort.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferShort;

  /// No description provided for @requestWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Request withdrawal'**
  String get requestWithdrawal;

  /// No description provided for @withdrawShort.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdrawShort;

  /// No description provided for @rechargeBalance.
  ///
  /// In en, this message translates to:
  /// **'Recharge balance'**
  String get rechargeBalance;

  /// No description provided for @rechargeBalanceNotice.
  ///
  /// In en, this message translates to:
  /// **'Recharged balance can only be spent and cannot be withdrawn'**
  String get rechargeBalanceNotice;

  /// No description provided for @customAmount.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get customAmount;

  /// No description provided for @rechargeAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter recharge amount'**
  String get rechargeAmountHint;

  /// No description provided for @recharge.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get recharge;

  /// No description provided for @transferAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a transfer amount'**
  String get transferAmountRequired;

  /// No description provided for @transferAmountTooHigh.
  ///
  /// In en, this message translates to:
  /// **'The transfer amount exceeds withdrawable commission'**
  String get transferAmountTooHigh;

  /// No description provided for @commissionTransferred.
  ///
  /// In en, this message translates to:
  /// **'Commission transferred to balance'**
  String get commissionTransferred;

  /// No description provided for @transferCommissionNotice.
  ///
  /// In en, this message translates to:
  /// **'Transfer withdrawable commission to your balance to purchase plans.'**
  String get transferCommissionNotice;

  /// No description provided for @transferAmount.
  ///
  /// In en, this message translates to:
  /// **'Transfer amount'**
  String get transferAmount;

  /// No description provided for @transferableAmount.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount}'**
  String transferableAmount(String amount);

  /// No description provided for @transferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring...'**
  String get transferring;

  /// No description provided for @confirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm transfer'**
  String get confirmTransfer;

  /// No description provided for @withdrawalAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a withdrawal amount'**
  String get withdrawalAmountRequired;

  /// No description provided for @withdrawalAmountTooHigh.
  ///
  /// In en, this message translates to:
  /// **'The withdrawal amount exceeds withdrawable commission'**
  String get withdrawalAmountTooHigh;

  /// No description provided for @minimumWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Minimum withdrawal: {amount}'**
  String minimumWithdrawal(String amount);

  /// No description provided for @withdrawalAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a withdrawal account'**
  String get withdrawalAccountRequired;

  /// No description provided for @withdrawalSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal ticket submitted'**
  String get withdrawalSubmitted;

  /// No description provided for @withdrawalMethod.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal method'**
  String get withdrawalMethod;

  /// No description provided for @withdrawalAccount.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal account'**
  String get withdrawalAccount;

  /// No description provided for @withdrawalAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the receiving account'**
  String get withdrawalAccountHint;

  /// No description provided for @withdrawalAmount.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal amount'**
  String get withdrawalAmount;

  /// No description provided for @withdrawableAmount.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable: {amount}'**
  String withdrawableAmount(String amount);

  /// No description provided for @withdrawableWithMinimum.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable: {amount} · Minimum: {minimum}'**
  String withdrawableWithMinimum(String amount, String minimum);

  /// No description provided for @submitWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Submit withdrawal'**
  String get submitWithdrawal;

  /// No description provided for @itemCopied.
  ///
  /// In en, this message translates to:
  /// **'{item} copied'**
  String itemCopied(String item);

  /// No description provided for @settingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Settings updated'**
  String get settingsUpdated;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myAccount;

  /// No description provided for @myAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View account and subscription details'**
  String get myAccountSubtitle;

  /// No description provided for @expiredStatus.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredStatus;

  /// No description provided for @suspendedStatus.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspendedStatus;

  /// No description provided for @normalStatus.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get normalStatus;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInformation;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get accountStatus;

  /// No description provided for @expiryTime.
  ///
  /// In en, this message translates to:
  /// **'Expiry time'**
  String get expiryTime;

  /// No description provided for @balanceAndRecharge.
  ///
  /// In en, this message translates to:
  /// **'Balance and recharge'**
  String get balanceAndRecharge;

  /// No description provided for @purchaseAndPayment.
  ///
  /// In en, this message translates to:
  /// **'Purchases and payments'**
  String get purchaseAndPayment;

  /// No description provided for @usageRecords.
  ///
  /// In en, this message translates to:
  /// **'Usage records'**
  String get usageRecords;

  /// No description provided for @contactAfterSales.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactAfterSales;

  /// No description provided for @resetDayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reset day --'**
  String get resetDayUnavailable;

  /// No description provided for @monthlyResetDay.
  ///
  /// In en, this message translates to:
  /// **'Resets on day {day} each month'**
  String monthlyResetDay(int day);

  /// No description provided for @trafficOverview.
  ///
  /// In en, this message translates to:
  /// **'Traffic overview'**
  String get trafficOverview;

  /// No description provided for @usedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String usedPercent(String percent);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @usedTraffic.
  ///
  /// In en, this message translates to:
  /// **'Used {used} / {total} GB'**
  String usedTraffic(String used, String total);

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan;

  /// No description provided for @noCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get noCurrentPlan;

  /// No description provided for @noPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'You do not have an active plan. Buy one to access nodes and traffic.'**
  String get noPlanDescription;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Your session and locally cached nodes will be cleared'**
  String get logoutDataNotice;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this account? You will need to sign in again.'**
  String get logoutConfirmMessage;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get confirmLogout;

  /// No description provided for @currentPlanValue.
  ///
  /// In en, this message translates to:
  /// **'Current plan: {plan}'**
  String currentPlanValue(String plan);

  /// No description provided for @expiryValue.
  ///
  /// In en, this message translates to:
  /// **'Expires: {expiry}'**
  String expiryValue(String expiry);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// No description provided for @expiryReminder.
  ///
  /// In en, this message translates to:
  /// **'Expiry reminder'**
  String get expiryReminder;

  /// No description provided for @expiryReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive account expiry reminders by email'**
  String get expiryReminderSubtitle;

  /// No description provided for @trafficReminder.
  ///
  /// In en, this message translates to:
  /// **'Traffic reminder'**
  String get trafficReminder;

  /// No description provided for @trafficReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive low-traffic reminders by email'**
  String get trafficReminderSubtitle;

  /// No description provided for @autoRenewal.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal'**
  String get autoRenewal;

  /// No description provided for @autoRenewalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically renew the plan before expiry'**
  String get autoRenewalSubtitle;

  /// No description provided for @updateLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Update your sign-in password'**
  String get updateLoginPassword;

  /// No description provided for @logoutCurrentAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this account'**
  String get logoutCurrentAccount;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The new password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the new password again'**
  String get confirmNewPasswordHint;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updating;

  /// No description provided for @confirmChange.
  ///
  /// In en, this message translates to:
  /// **'Confirm change'**
  String get confirmChange;

  /// No description provided for @trayConnectedTun.
  ///
  /// In en, this message translates to:
  /// **'Connected · TUN'**
  String get trayConnectedTun;

  /// No description provided for @trayConnectedSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Connected · System proxy'**
  String get trayConnectedSystemProxy;

  /// No description provided for @openApp.
  ///
  /// In en, this message translates to:
  /// **'Open {appName}'**
  String openApp(String appName);

  /// No description provided for @trayNode.
  ///
  /// In en, this message translates to:
  /// **'Node: {node}'**
  String trayNode(String node);

  /// No description provided for @connectNow.
  ///
  /// In en, this message translates to:
  /// **'Connect now'**
  String get connectNow;

  /// No description provided for @repairSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Repair system proxy'**
  String get repairSystemProxy;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @cannotOpenUpdateUrl.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the update download URL'**
  String get cannotOpenUpdateUrl;

  /// No description provided for @downloadPageOpened.
  ///
  /// In en, this message translates to:
  /// **'Download page opened'**
  String get downloadPageOpened;

  /// No description provided for @downloadCompleteOpeningInstaller.
  ///
  /// In en, this message translates to:
  /// **'Download complete. Opening installer...'**
  String get downloadCompleteOpeningInstaller;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version v{version} is available. Download the latest version.'**
  String newVersionAvailable(String version);

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download now'**
  String get downloadNow;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @backToAccount.
  ///
  /// In en, this message translates to:
  /// **'Back to account'**
  String get backToAccount;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed. Try again later.'**
  String get requestFailed;

  /// No description provided for @sessionExpiredError.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get sessionExpiredError;

  /// No description provided for @tooManyRequestsError.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyRequestsError;

  /// No description provided for @invalidSubmissionError.
  ///
  /// In en, this message translates to:
  /// **'Some information is invalid. Check it and try again.'**
  String get invalidSubmissionError;

  /// No description provided for @connectionTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check your network and try again.'**
  String get connectionTimeoutError;

  /// No description provided for @cannotConnectServerError.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Check your network.'**
  String get cannotConnectServerError;

  /// No description provided for @serverUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Try again later.'**
  String get serverUnavailableError;

  /// No description provided for @invalidServerResponseError.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid response. Try again later.'**
  String get invalidServerResponseError;

  /// No description provided for @unsafeSubscriptionError.
  ///
  /// In en, this message translates to:
  /// **'The subscription URL is not secure and was rejected.'**
  String get unsafeSubscriptionError;

  /// No description provided for @serverNotConfiguredError.
  ///
  /// In en, this message translates to:
  /// **'The server address is not configured.'**
  String get serverNotConfiguredError;

  /// No description provided for @installerVerificationError.
  ///
  /// In en, this message translates to:
  /// **'Installer verification failed. Download it again.'**
  String get installerVerificationError;

  /// No description provided for @updateDownloadError.
  ///
  /// In en, this message translates to:
  /// **'Update download failed. Try again later.'**
  String get updateDownloadError;

  /// No description provided for @networkRequestError.
  ///
  /// In en, this message translates to:
  /// **'Network request failed. Check your connection and try again.'**
  String get networkRequestError;

  /// No description provided for @invalidCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidCredentialsError;

  /// No description provided for @invalidVerificationCodeError.
  ///
  /// In en, this message translates to:
  /// **'The verification code is invalid or expired.'**
  String get invalidVerificationCodeError;

  /// No description provided for @accountDisabledError.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support.'**
  String get accountDisabledError;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again later.'**
  String get unexpectedError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
