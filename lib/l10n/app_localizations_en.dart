// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pointer';

  @override
  String get compassTitle => 'Pointer';

  @override
  String distanceUnit_m(Object distance) {
    return '${distance}m';
  }

  @override
  String distanceUnit_km(Object distance) {
    return '$distance km';
  }

  @override
  String get inviteCodeLabel => 'My invite code';

  @override
  String get inviteCodeRefreshDaily => 'Refresh daily';

  @override
  String get inviteCodeRefreshOnDemand => 'Refresh manually';

  @override
  String get connectInputHint => 'Enter peer invite code';

  @override
  String get connectWaiting => 'Waiting for approval…';

  @override
  String get connectApprove => 'Approve';

  @override
  String get connectReject => 'Reject';

  @override
  String connectRequestTitle(Object name) {
    return '$name wants to connect';
  }

  @override
  String get connectRequestBody => 'Allow this device to share location with you?';

  @override
  String get peerOnline => 'Online';

  @override
  String get peerOffline => 'Peer is offline';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionInvite => 'My invite code';

  @override
  String get settingsSectionDevices => 'Paired devices';

  @override
  String get settingsSectionBackground => 'Background & location';

  @override
  String get settingsSectionWidget => 'Home widget';

  @override
  String get backgroundRunning => 'Running in background';

  @override
  String get locationAccuracyHigh => 'High accuracy';

  @override
  String get locationAccuracySaving => 'Battery saving';

  @override
  String get permissionDeniedTitle => 'Location permission required';

  @override
  String get permissionDeniedBody => 'Pointer needs access to your location to calculate direction and distance';

  @override
  String get permissionGoToSettings => 'Grant permission';

  @override
  String get noTargetSelected => 'Select a target location to start';

  @override
  String get addLocation => 'Add location';

  @override
  String get locationNameHint => 'Name this location';

  @override
  String get saveLocation => 'Save';

  @override
  String get deleteConnection => 'Remove pairing';

  @override
  String get retry => 'Retry';

  @override
  String get gpsUnavailable => 'GPS is unavailable or accuracy is insufficient';

  @override
  String get compassUnavailable => 'Compass is not available on this device';

  @override
  String get inviteCodeExpired => 'Invite code has expired';

  @override
  String get inviteCodeInvalid => 'Invalid invite code';

  @override
  String get connectionTimeout => 'Connection timed out. Please try again.';

  @override
  String get peerRejected => 'Peer rejected the request';

  @override
  String get webSocketDisconnected => 'Disconnected. Please check your network.';

  @override
  String get unknownError => 'Something went wrong. Please try again.';
}
