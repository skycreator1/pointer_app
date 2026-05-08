import 'package:permission_handler/permission_handler.dart';
import 'package:pointer_app/l10n/app_localizations.dart';

abstract class AppException implements Exception {
  const AppException();

  String userMessage(AppLocalizations l10n);
}

class UnknownException extends AppException {
  const UnknownException(this.error, this.stackTrace);

  final Object error;
  final StackTrace? stackTrace;

  @override
  String userMessage(AppLocalizations l10n) => l10n.unknownError;
}

class GpsUnavailableException extends AppException {
  const GpsUnavailableException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.gpsUnavailable;
}

class CompassUnavailableException extends AppException {
  const CompassUnavailableException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.compassUnavailable;
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException(this.permission);

  final Permission permission;

  @override
  String userMessage(AppLocalizations l10n) => l10n.permissionDeniedBody;
}

class InviteCodeExpiredException extends AppException {
  const InviteCodeExpiredException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.inviteCodeExpired;
}

class InviteCodeInvalidException extends AppException {
  const InviteCodeInvalidException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.inviteCodeInvalid;
}

class ConnectionTimeoutException extends AppException {
  const ConnectionTimeoutException({this.timeout = const Duration(seconds: 30)});

  final Duration timeout;

  @override
  String userMessage(AppLocalizations l10n) => l10n.connectionTimeout;
}

class PeerRejectedException extends AppException {
  const PeerRejectedException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.peerRejected;
}

class WebSocketException extends AppException {
  const WebSocketException(this.originalError);

  final Object originalError;

  @override
  String userMessage(AppLocalizations l10n) => l10n.webSocketDisconnected;
}

