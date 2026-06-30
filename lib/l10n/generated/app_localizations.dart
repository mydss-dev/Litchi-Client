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
  /// **'Language'**
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
  /// **'Connection interruption protection'**
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
  /// **'Repair network settings'**
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

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

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

  /// No description provided for @missingCoreError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. The mihomo core is missing.'**
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
