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
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Pointer'**
  String get appName;

  /// No description provided for @compassTitle.
  ///
  /// In en, this message translates to:
  /// **'Pointer'**
  String get compassTitle;

  /// No description provided for @distanceUnit_m.
  ///
  /// In en, this message translates to:
  /// **'{distance}m'**
  String distanceUnit_m(Object distance);

  /// No description provided for @distanceUnit_km.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String distanceUnit_km(Object distance);

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'My invite code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeRefreshDaily.
  ///
  /// In en, this message translates to:
  /// **'Refresh daily'**
  String get inviteCodeRefreshDaily;

  /// No description provided for @inviteCodeRefreshOnDemand.
  ///
  /// In en, this message translates to:
  /// **'Refresh manually'**
  String get inviteCodeRefreshOnDemand;

  /// No description provided for @connectInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter peer invite code'**
  String get connectInputHint;

  /// No description provided for @connectWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval…'**
  String get connectWaiting;

  /// No description provided for @connectApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get connectApprove;

  /// No description provided for @connectReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get connectReject;

  /// No description provided for @connectRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect'**
  String connectRequestTitle(Object name);

  /// No description provided for @connectRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Allow this device to share location with you?'**
  String get connectRequestBody;

  /// No description provided for @peerOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get peerOnline;

  /// No description provided for @peerOffline.
  ///
  /// In en, this message translates to:
  /// **'Peer is offline'**
  String get peerOffline;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionInvite.
  ///
  /// In en, this message translates to:
  /// **'My invite code'**
  String get settingsSectionInvite;

  /// No description provided for @settingsSectionDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get settingsSectionDevices;

  /// No description provided for @settingsSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Background & location'**
  String get settingsSectionBackground;

  /// No description provided for @settingsSectionWidget.
  ///
  /// In en, this message translates to:
  /// **'Home widget'**
  String get settingsSectionWidget;

  /// No description provided for @backgroundRunning.
  ///
  /// In en, this message translates to:
  /// **'Running in background'**
  String get backgroundRunning;

  /// No description provided for @locationAccuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'High accuracy'**
  String get locationAccuracyHigh;

  /// No description provided for @locationAccuracySaving.
  ///
  /// In en, this message translates to:
  /// **'Battery saving'**
  String get locationAccuracySaving;

  /// No description provided for @permissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location permission required'**
  String get permissionDeniedTitle;

  /// No description provided for @permissionDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Pointer needs access to your location to calculate direction and distance'**
  String get permissionDeniedBody;

  /// No description provided for @permissionGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get permissionGoToSettings;

  /// No description provided for @noTargetSelected.
  ///
  /// In en, this message translates to:
  /// **'Select a target location to start'**
  String get noTargetSelected;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocation;

  /// No description provided for @locationNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name this location'**
  String get locationNameHint;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLocation;

  /// No description provided for @deleteConnection.
  ///
  /// In en, this message translates to:
  /// **'Remove pairing'**
  String get deleteConnection;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS is unavailable or accuracy is insufficient'**
  String get gpsUnavailable;

  /// No description provided for @compassUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Compass is not available on this device'**
  String get compassUnavailable;

  /// No description provided for @inviteCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite code has expired'**
  String get inviteCodeExpired;

  /// No description provided for @inviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code'**
  String get inviteCodeInvalid;

  /// No description provided for @connectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please try again.'**
  String get connectionTimeout;

  /// No description provided for @peerRejected.
  ///
  /// In en, this message translates to:
  /// **'Peer rejected the request'**
  String get peerRejected;

  /// No description provided for @webSocketDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Please check your network.'**
  String get webSocketDisconnected;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownError;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
