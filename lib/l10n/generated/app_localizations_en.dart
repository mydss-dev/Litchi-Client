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
  String get silentStartup => 'Start silently in tray';

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

  @override
  String get fillEmailPrefix => 'Enter the email prefix first';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get verificationCodeSent =>
      'Verification code sent. Check your email.';

  @override
  String get passwordsMismatch => 'The passwords do not match';

  @override
  String get verificationCodeRequired => 'Enter the email verification code';

  @override
  String get acceptTermsRequired => 'Accept the Terms of Service first';

  @override
  String registrationSuccess(String appName) {
    return 'Welcome to $appName!';
  }

  @override
  String get verificationCode => 'Verification code';

  @override
  String get verificationCodeHint => 'Enter the email verification code';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Enter the password again';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteCodeOptional => 'Invite code (optional)';

  @override
  String get termsAgreementPrefix => 'I have read and agree to ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get sendVerificationCode => 'Send code';

  @override
  String get sending => 'Sending…';

  @override
  String resendIn(int seconds) {
    return 'Resend (${seconds}s)';
  }

  @override
  String get resend => 'Resend';

  @override
  String get allFieldsRequired => 'Complete all fields';

  @override
  String get passwordResetSuccess => 'Password reset. Sign in again.';

  @override
  String get registeredEmailHint => 'Enter your registered email';

  @override
  String get newPassword => 'New password';

  @override
  String get newPasswordHint => 'Enter a new password';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get passwordFieldsRequired => 'Complete all password fields';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get currentPasswordHint => 'Enter your current password';

  @override
  String get passwordAdvice =>
      'Use at least 8 characters with letters and numbers';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get refreshed => 'Refreshed';

  @override
  String get connectionSuccess => 'Connected';

  @override
  String get dashboardSubtitle => 'View connection, node and traffic status';

  @override
  String get all => 'All';

  @override
  String get favorites => 'Favorites';

  @override
  String get asia => 'Asia';

  @override
  String get europe => 'Europe';

  @override
  String get america => 'Americas';

  @override
  String get oceania => 'Oceania';

  @override
  String get nodesSubtitle => 'Choose a fast route';

  @override
  String get selectLineAndLatency => 'Choose a route and view latency';

  @override
  String get noMatchingNodes => 'No matching nodes';

  @override
  String get tryDifferentNodeFilter => 'Try another keyword or region';

  @override
  String get searchNodes => 'Search nodes';

  @override
  String get autoSelect => 'Auto select';

  @override
  String get manualSelect => 'Manual select';

  @override
  String get autoSelectBestDescription =>
      'Automatically use the lowest-latency route';

  @override
  String get autoSelectEnabled =>
      'Auto select enabled. The best node will be used.';

  @override
  String switchedToNode(String node) {
    return 'Switched to $node';
  }

  @override
  String get noTestableNodes => 'No nodes available for testing';

  @override
  String get latencyTestComplete => 'Latency test completed';

  @override
  String get latencyTestFailed =>
      'Latency test failed. Check the nodes and try again.';

  @override
  String get latencyTest => 'Test latency';

  @override
  String get noNodes => 'No nodes';

  @override
  String get waitForSubscription =>
      'If you just signed in, wait for subscription data to load';

  @override
  String get chooseNode => 'Choose node';

  @override
  String nodeCountSummary(int count) {
    return '$count nodes · Filter routes and view latency';
  }

  @override
  String get noNodesSubscription => 'No nodes · Check subscription status';

  @override
  String get close => 'Close';

  @override
  String get currentNode => 'Current node';

  @override
  String get nodeLoading => 'Loading nodes';

  @override
  String get nodeStatus => 'Node status';

  @override
  String get fetchingNodes => 'Fetching nodes...';

  @override
  String get noAvailableNodes => 'No available nodes';

  @override
  String get syncingSubscription => 'Syncing subscription data...';

  @override
  String get subscriptionLoadsAfterLogin =>
      'Subscription nodes load automatically after sign-in';

  @override
  String get encryptionProtectionEnabled => 'Encrypted protection is active';

  @override
  String get establishingEncryptedChannel =>
      'Establishing encrypted channel...';

  @override
  String get closingEncryptedChannel => 'Closing encrypted channel...';

  @override
  String get networkNotProtected =>
      'Network traffic is not currently protected';

  @override
  String nodeMode(String mode) {
    return 'Node mode · $mode';
  }

  @override
  String get switchNode => 'Switch node';

  @override
  String get viewNodes => 'View nodes';

  @override
  String get startConnection => 'Connect';

  @override
  String get connecting => 'Connecting…';

  @override
  String get disconnectConnection => 'Disconnect';

  @override
  String get disconnecting => 'Disconnecting…';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get proxyModeDescriptionRule =>
      'Route local traffic directly and other traffic through the proxy';

  @override
  String get proxyModeDescriptionGlobal =>
      'Route all traffic through the proxy node';

  @override
  String get proxyModeDescriptionDirect =>
      'Connect directly without using the proxy';

  @override
  String switchedProxyMode(String mode) {
    return 'Switched to $mode';
  }

  @override
  String get proxyModeNextConnection =>
      'The proxy mode applies on the next connection';

  @override
  String get ruleMode => 'Rule';

  @override
  String get globalMode => 'Global';

  @override
  String get directMode => 'Direct';

  @override
  String get currentLatency => 'Latency';

  @override
  String get downloadSpeed => 'Download';

  @override
  String get uploadSpeed => 'Upload';

  @override
  String get subscriptionExpired =>
      'Subscription expired. Connection is unavailable.';

  @override
  String get subscriptionExpiresToday =>
      'Subscription expires today. Renew now.';

  @override
  String subscriptionExpiresInDays(int days) {
    return 'Subscription expires in $days days';
  }

  @override
  String get renewNow => 'Renew →';

  @override
  String get retry => 'Retry';

  @override
  String get businessEdition => 'Business edition';

  @override
  String get protected => 'Protected';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get notConnected => 'Not connected';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get androidLimitedNotice =>
      'This Android version currently supports sign-in, purchases and node viewing';

  @override
  String get syncingNodes => 'Syncing nodes...';

  @override
  String get selectNodePrompt => 'Select a node';

  @override
  String nodeModeLabel(String mode) {
    return 'Node mode: $mode';
  }

  @override
  String get buyPlans => 'Buy plans';

  @override
  String get buyPlansSubtitle => 'Choose a plan or data pack';

  @override
  String get planPurchase => 'Plans';

  @override
  String get recurringPlan => 'Recurring';

  @override
  String get oneTime => 'One-time';

  @override
  String get dataPack => 'Data pack';

  @override
  String get noPlans => 'No plans available';

  @override
  String get refreshLater => 'Refresh and try again later';

  @override
  String get unlimitedTime => '/ No expiry';

  @override
  String get oneTimePlan => 'One-time plan';

  @override
  String devicesCount(int count) {
    return '$count devices';
  }

  @override
  String get unlimitedDevices => 'Unlimited devices';

  @override
  String get popular => 'Popular';

  @override
  String get recommended => 'Recommended';

  @override
  String get buyNow => 'Buy now';

  @override
  String get unavailableForPurchase => 'Unavailable';

  @override
  String get monthly => 'Monthly';

  @override
  String get quarterly => 'Quarterly';

  @override
  String get halfYear => 'Half-year';

  @override
  String get yearly => 'Yearly';

  @override
  String get perMonth => '/ month';

  @override
  String get perQuarter => '/ quarter';

  @override
  String get perHalfYear => '/ half-year';

  @override
  String get perYear => '/ year';

  @override
  String get orderHistorySubtitle => 'View purchases and payments';

  @override
  String get order => 'Order';

  @override
  String get orderLoadFailed => 'Failed to load orders';

  @override
  String get noOrders => 'No orders';

  @override
  String get ordersAppearAfterPurchase => 'Purchased plans will appear here';

  @override
  String get orderCancelled => 'Order cancelled';

  @override
  String get accountTopUp => 'Account top-up';

  @override
  String orderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get type => 'Type';

  @override
  String get date => 'Date';

  @override
  String get amount => 'Amount';

  @override
  String get status => 'Status';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get continuePayment => 'Continue payment';

  @override
  String get processing => 'Processing';

  @override
  String get cancelOrderConfirm =>
      'Cancel this unpaid order? You will need to place it again.';

  @override
  String get thinkAgain => 'Keep order';

  @override
  String get confirmCancel => 'Confirm cancellation';

  @override
  String get inviteFriends => 'Invite friends';

  @override
  String get inviteSubtitle =>
      'Share your invite link and view commission records';

  @override
  String get inviteCommission => 'Referral commission';

  @override
  String get inviteCodeCreated => 'Invite code created';

  @override
  String get inviteLink => 'Invite link';

  @override
  String get copyLink => 'Copy link';

  @override
  String get creating => 'Creating';

  @override
  String get createInviteCode => 'Create invite code';

  @override
  String inviteCodeIndex(int index) {
    return 'Invite code $index';
  }

  @override
  String get inviteLinkUnavailable => 'Invite link is not configured';

  @override
  String get registeredUsers => 'Registered users';

  @override
  String peopleCount(int count) {
    return '$count users';
  }

  @override
  String get pendingCommission => 'Pending commission';

  @override
  String get totalCommission => 'Total commission';

  @override
  String get commissionRate => 'Commission rate';

  @override
  String get commissionRecords => 'Commission records';

  @override
  String get noCommissionRecords => 'No commission records';

  @override
  String get invitedUser => 'Invited user';

  @override
  String recordOrderAmount(String date, String amount) {
    return '$date · Order $amount';
  }

  @override
  String get copied => 'Copied';

  @override
  String linkCopiedForApp(String app) {
    return 'Link copied. Paste it into $app';
  }

  @override
  String get confirmOrder => 'Confirm order';

  @override
  String get selectBillingCycle => 'Select billing cycle';

  @override
  String get couponCode => 'Coupon code';

  @override
  String get couponHint => 'Enter coupon code (optional)';

  @override
  String get remove => 'Remove';

  @override
  String get verifying => 'Verifying…';

  @override
  String get verify => 'Verify';

  @override
  String get couponApplied => 'Coupon applied';

  @override
  String get invalidCoupon => 'Invalid coupon';

  @override
  String discountAmount(String amount) {
    return 'Discount $amount';
  }

  @override
  String discountPercent(int percent) {
    return '$percent% off';
  }

  @override
  String get originalPrice => 'Original price';

  @override
  String get discount => 'Discount';

  @override
  String get totalDue => 'Total due';

  @override
  String get cancel => 'Cancel';

  @override
  String get submitOrder => 'Submit order';

  @override
  String operationFailed(String operation, String error) {
    return '$operation failed: $error';
  }

  @override
  String get selectPaymentMethod => 'Select payment method';

  @override
  String get browserPayment => 'Browser payment';

  @override
  String get scanToPay => 'Scan to pay';

  @override
  String get paymentSuccess => 'Payment successful';

  @override
  String get paymentTimedOut => 'Payment timed out';

  @override
  String get qrExpired => 'QR code expired';

  @override
  String get amountDue => 'Amount due';

  @override
  String get choosePaymentMethod => 'Choose a payment method';

  @override
  String get noPaymentMethods => 'No payment methods available';

  @override
  String get payNow => 'Pay now';

  @override
  String get scanWithPhone => 'Scan with your phone to complete payment';

  @override
  String get openInBrowser => 'or open in a browser';

  @override
  String remainingTime(String time) {
    return '$time remaining';
  }

  @override
  String get paymentCompleted => 'I have completed payment';

  @override
  String get paymentNotDetected => 'Payment not detected. Try again shortly.';

  @override
  String get orderActivated => 'The order is active. Refresh to view it.';

  @override
  String get done => 'Done';

  @override
  String get refreshQrCode => 'Refresh QR code';

  @override
  String get getPaymentMethods => 'Get payment methods';

  @override
  String get startPayment => 'Start payment';

  @override
  String get queryPayment => 'Check payment';

  @override
  String get refreshPayment => 'Refresh payment';

  @override
  String get orderPending => 'Pending payment';

  @override
  String get orderProcessing => 'Processing';

  @override
  String get orderCancelledStatus => 'Cancelled';

  @override
  String get orderCompleted => 'Completed';

  @override
  String get orderFailed => 'Failed';

  @override
  String get twoYears => 'Two years';

  @override
  String get threeYears => 'Three years';

  @override
  String get refunded => 'Refunded';

  @override
  String get unknown => 'Unknown';

  @override
  String get buyout => 'Lifetime';

  @override
  String get wechat => 'WeChat';

  @override
  String get connectionInProgress => 'Connection in progress';

  @override
  String get connected => 'Connected';

  @override
  String diagnosticPlatform(String platform) {
    return 'Platform: $platform';
  }

  @override
  String diagnosticConnectionStatus(String status) {
    return 'Connection status: $status';
  }

  @override
  String diagnosticProxyPort(int port) {
    return 'Local proxy port: $port';
  }

  @override
  String diagnosticRecordedAt(String time) {
    return 'Recorded at: $time';
  }

  @override
  String diagnosticRecentError(String error) {
    return 'Recent error: $error';
  }

  @override
  String get noRuntimeLogs => 'No runtime logs yet. Try connecting first.';

  @override
  String get systemDns => 'System DNS';

  @override
  String get httpSecurityWarning =>
      'The current server uses HTTP. Data is not encrypted and may be intercepted. Ask the provider to enable HTTPS.';

  @override
  String get diagnosticCopyDescription =>
      'Copy and send this to support to help diagnose the issue';

  @override
  String get diagnosticCopied => 'Diagnostics copied. Send them to support.';

  @override
  String get copyDiagnostics => 'Copy diagnostics';

  @override
  String get restartClientError =>
      'Connection failed. Restart the client and try again.';

  @override
  String get proxyPortUnavailableError =>
      'The local proxy port did not start. Close other proxy apps and try again.';

  @override
  String get missingCoreError =>
      'Connection failed. The mihomo core is missing.';

  @override
  String get permissionDeniedError =>
      'Permission denied. Run the client as administrator.';

  @override
  String get tunInterfaceUnavailableError =>
      'TUN adapter failed to start. Check system permission and try again.';

  @override
  String get tunKillSwitchUnavailableError =>
      'TUN interruption protection failed. Connection was stopped to prevent leaks.';

  @override
  String get androidStartFailedError => 'Android core failed to start';

  @override
  String get unexpectedCoreExitError =>
      'The core exited unexpectedly. Reconnect to continue.';

  @override
  String get invalidNodeConfigError =>
      'The selected node is invalid. Choose another node.';

  @override
  String get genericConnectionFailureError =>
      'Connection failed. Change nodes or try again later.';

  @override
  String get configBuildFailedError =>
      'Failed to generate configuration. Choose another node.';

  @override
  String get cachedModeActive =>
      'Server connection failed. Cached mode is active and saved nodes remain available.';

  @override
  String get serverUnavailableNoCache =>
      'The server is unavailable and no nodes are cached. Check the network or contact support.';

  @override
  String get trafficStatistics => 'Traffic statistics';

  @override
  String get trafficStatisticsSubtitle =>
      'View traffic, devices and plan cycle';

  @override
  String remainingTraffic(String value) {
    return '$value GB remaining';
  }

  @override
  String get onlineDevices => 'Online devices';

  @override
  String get currentOnlineDevices => 'Devices currently online';

  @override
  String get remainingDays => 'Days remaining';

  @override
  String get permanent => 'Permanent';

  @override
  String get daysUnit => 'days';

  @override
  String get subscriptionLongTerm => 'Subscription does not expire';

  @override
  String expiresAt(String date) {
    return 'Expires $date';
  }

  @override
  String get trafficResetTime => 'Traffic reset';

  @override
  String get neverResets => 'Never resets';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get noTrafficReset => 'This plan has no traffic reset cycle';

  @override
  String get untilNextReset => 'Until next reset';

  @override
  String get trafficTrend => 'Traffic trend';

  @override
  String periodTrafficTotal(String period, String total) {
    return '$period · $total total';
  }

  @override
  String recentDays(int count) {
    return 'Last $count days';
  }

  @override
  String tooltipUpload(String value) {
    return 'Upload $value';
  }

  @override
  String tooltipDownload(String value) {
    return 'Download $value';
  }

  @override
  String tooltipTotal(String value) {
    return 'Total $value';
  }

  @override
  String get weekdayShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get ticketSupport => 'Ticket support';

  @override
  String get ticketSupportSubtitle => 'Submit an issue and view replies';

  @override
  String get tickets => 'Tickets';

  @override
  String get ticketSupportCompactSubtitle =>
      'Submit issues and view support replies';

  @override
  String get newTicket => 'New ticket';

  @override
  String get ticketLoadFailed => 'Failed to load tickets';

  @override
  String get noTickets => 'No tickets';

  @override
  String get noTicketsSubtitle => 'Create a ticket to contact support';

  @override
  String get untitledTicket => 'Untitled ticket';

  @override
  String get ticketFieldsRequired => 'Enter a subject and issue description';

  @override
  String get ticketSubjectTooShort =>
      'The subject must be at least 5 characters';

  @override
  String get ticketMessageTooShort =>
      'The description must be at least 10 characters';

  @override
  String get ticketSubmitted => 'Ticket submitted';

  @override
  String get issueSubject => 'Subject';

  @override
  String get issueSubjectHint => 'Describe the issue in one sentence';

  @override
  String get priority => 'Priority';

  @override
  String get issueDescription => 'Issue description';

  @override
  String get issueDescriptionHint => 'Describe the issue in detail';

  @override
  String get submitting => 'Submitting...';

  @override
  String get submitTicket => 'Submit ticket';

  @override
  String get replyRequired => 'Enter a reply';

  @override
  String get replySent => 'Reply sent';

  @override
  String get ticketClosed => 'Ticket closed';

  @override
  String get ticketDetails => 'Ticket details';

  @override
  String get replyHint => 'Enter your reply';

  @override
  String get closing => 'Closing...';

  @override
  String get closeTicket => 'Close ticket';

  @override
  String get sendReply => 'Send reply';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get noTicketMessages => 'No messages yet';

  @override
  String get customerSupport => 'Support';

  @override
  String get me => 'Me';

  @override
  String get ticketClosedStatus => 'Closed';

  @override
  String get invalidRechargeAmount => 'Enter a valid recharge amount';

  @override
  String get noTransferableCommission => 'No commission available to transfer';

  @override
  String get withdrawalUnavailable => 'Withdrawals are currently unavailable';

  @override
  String get noWithdrawableCommission => 'No commission available to withdraw';

  @override
  String get noWithdrawalMethods => 'No withdrawal methods are available';

  @override
  String get myWallet => 'My wallet';

  @override
  String get myWalletSubtitle => 'View balance, commission and recharge';

  @override
  String get accountAssets => 'Account assets';

  @override
  String get accountBalance => 'Account balance';

  @override
  String get withdrawableCommission => 'Withdrawable commission';

  @override
  String get transferCommission => 'Transfer commission';

  @override
  String get requestWithdrawal => 'Request withdrawal';

  @override
  String get rechargeBalance => 'Recharge balance';

  @override
  String get rechargeBalanceNotice =>
      'Recharged balance can only be spent and cannot be withdrawn';

  @override
  String get customAmount => 'Custom amount';

  @override
  String get rechargeAmountHint => 'Enter recharge amount';

  @override
  String get recharge => 'Recharge';

  @override
  String get transferAmountRequired => 'Enter a transfer amount';

  @override
  String get transferAmountTooHigh =>
      'The transfer amount exceeds withdrawable commission';

  @override
  String get commissionTransferred => 'Commission transferred to balance';

  @override
  String get transferCommissionNotice =>
      'Transfer withdrawable commission to your balance to purchase plans.';

  @override
  String get transferAmount => 'Transfer amount';

  @override
  String transferableAmount(String amount) {
    return 'Available: $amount';
  }

  @override
  String get transferring => 'Transferring...';

  @override
  String get confirmTransfer => 'Confirm transfer';

  @override
  String get withdrawalAmountRequired => 'Enter a withdrawal amount';

  @override
  String get withdrawalAmountTooHigh =>
      'The withdrawal amount exceeds withdrawable commission';

  @override
  String minimumWithdrawal(String amount) {
    return 'Minimum withdrawal: $amount';
  }

  @override
  String get withdrawalAccountRequired => 'Enter a withdrawal account';

  @override
  String get withdrawalSubmitted => 'Withdrawal ticket submitted';

  @override
  String get withdrawalMethod => 'Withdrawal method';

  @override
  String get withdrawalAccount => 'Withdrawal account';

  @override
  String get withdrawalAccountHint => 'Enter the receiving account';

  @override
  String get withdrawalAmount => 'Withdrawal amount';

  @override
  String withdrawableAmount(String amount) {
    return 'Withdrawable: $amount';
  }

  @override
  String withdrawableWithMinimum(String amount, String minimum) {
    return 'Withdrawable: $amount · Minimum: $minimum';
  }

  @override
  String get submitWithdrawal => 'Submit withdrawal';

  @override
  String itemCopied(String item) {
    return '$item copied';
  }

  @override
  String get settingsUpdated => 'Settings updated';

  @override
  String get myAccount => 'My account';

  @override
  String get myAccountSubtitle => 'View account and subscription details';

  @override
  String get expiredStatus => 'Expired';

  @override
  String get suspendedStatus => 'Suspended';

  @override
  String get normalStatus => 'Active';

  @override
  String get accountInformation => 'Account information';

  @override
  String get accountStatus => 'Account status';

  @override
  String get expiryTime => 'Expiry time';

  @override
  String get balanceAndRecharge => 'Balance and recharge';

  @override
  String get purchaseAndPayment => 'Purchases and payments';

  @override
  String get usageRecords => 'Usage records';

  @override
  String get contactAfterSales => 'Contact support';

  @override
  String get resetDayUnavailable => 'Reset day --';

  @override
  String monthlyResetDay(int day) {
    return 'Resets on day $day each month';
  }

  @override
  String get trafficOverview => 'Traffic overview';

  @override
  String usedPercent(String percent) {
    return '$percent% used';
  }

  @override
  String get remaining => 'Remaining';

  @override
  String usedTraffic(String used, String total) {
    return 'Used $used / $total GB';
  }

  @override
  String get currentPlan => 'Current plan';

  @override
  String get noCurrentPlan => 'No active plan';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutDataNotice =>
      'Your session and locally cached nodes will be cleared';

  @override
  String get logoutConfirmMessage =>
      'Sign out of this account? You will need to sign in again.';

  @override
  String get confirmLogout => 'Sign out';

  @override
  String currentPlanValue(String plan) {
    return 'Current plan: $plan';
  }

  @override
  String expiryValue(String expiry) {
    return 'Expires: $expiry';
  }

  @override
  String get manage => 'Manage';

  @override
  String get accountManagement => 'Account management';

  @override
  String get expiryReminder => 'Expiry reminder';

  @override
  String get expiryReminderSubtitle =>
      'Receive account expiry reminders by email';

  @override
  String get trafficReminder => 'Traffic reminder';

  @override
  String get trafficReminderSubtitle =>
      'Receive low-traffic reminders by email';

  @override
  String get autoRenewal => 'Auto renewal';

  @override
  String get autoRenewalSubtitle =>
      'Automatically renew the plan before expiry';

  @override
  String get updateLoginPassword => 'Update your sign-in password';

  @override
  String get logoutCurrentAccount => 'Sign out of this account';

  @override
  String get passwordTooShort =>
      'The new password must be at least 8 characters';

  @override
  String get currentPassword => 'Current password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get confirmNewPasswordHint => 'Enter the new password again';

  @override
  String get updating => 'Updating...';

  @override
  String get confirmChange => 'Confirm change';

  @override
  String get trayConnectedTun => 'Connected · TUN';

  @override
  String get trayConnectedSystemProxy => 'Connected · System proxy';

  @override
  String openApp(String appName) {
    return 'Open $appName';
  }

  @override
  String trayNode(String node) {
    return 'Node: $node';
  }

  @override
  String get connectNow => 'Connect now';

  @override
  String get repairSystemProxy => 'Repair system proxy';

  @override
  String get quit => 'Quit';

  @override
  String get cannotOpenUpdateUrl => 'Unable to open the update download URL';

  @override
  String get downloadPageOpened => 'Download page opened';

  @override
  String get downloadCompleteOpeningInstaller =>
      'Download complete. Opening installer...';

  @override
  String newVersionAvailable(String version) {
    return 'Version v$version is available. Download the latest version.';
  }

  @override
  String get downloadNow => 'Download now';

  @override
  String get refresh => 'Refresh';

  @override
  String get back => 'Back';

  @override
  String get search => 'Search';

  @override
  String get backToAccount => 'Back to account';

  @override
  String get viewDetails => 'View details';

  @override
  String get requestFailed => 'Request failed. Try again later.';

  @override
  String get sessionExpiredError => 'Your session has expired. Sign in again.';

  @override
  String get tooManyRequestsError => 'Too many attempts. Try again later.';

  @override
  String get invalidSubmissionError =>
      'Some information is invalid. Check it and try again.';

  @override
  String get connectionTimeoutError =>
      'Connection timed out. Check your network and try again.';

  @override
  String get cannotConnectServerError =>
      'Unable to connect to the server. Check your network.';

  @override
  String get serverUnavailableError =>
      'The server is temporarily unavailable. Try again later.';

  @override
  String get invalidServerResponseError =>
      'The server returned an invalid response. Try again later.';

  @override
  String get unsafeSubscriptionError =>
      'The subscription URL is not secure and was rejected.';

  @override
  String get serverNotConfiguredError =>
      'The server address is not configured.';

  @override
  String get installerVerificationError =>
      'Installer verification failed. Download it again.';

  @override
  String get updateDownloadError => 'Update download failed. Try again later.';

  @override
  String get networkRequestError =>
      'Network request failed. Check your connection and try again.';

  @override
  String get invalidCredentialsError => 'Incorrect email or password.';

  @override
  String get invalidVerificationCodeError =>
      'The verification code is invalid or expired.';

  @override
  String get accountDisabledError =>
      'This account has been disabled. Contact support.';

  @override
  String get unexpectedError => 'Something went wrong. Try again later.';

  @override
  String get nodeSortOriginal => 'Default order';

  @override
  String get nodeSortLatency => 'By latency';

  @override
  String get nodeSortName => 'By name';

  @override
  String get nodeSortRegion => 'By region';
}
