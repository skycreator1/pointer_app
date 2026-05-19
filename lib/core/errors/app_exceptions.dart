// Domain exceptions surfaced to the UI.
//
// Each exception provides a localized user-facing message via AppLocalizations.
import 'package:permission_handler/permission_handler.dart';
import 'package:pointer_app/l10n/app_localizations.dart';

sealed class AppException implements Exception {
  const AppException();

  String userMessage(AppLocalizations l10n);
}

final class PermissionDeniedException extends AppException {
  const PermissionDeniedException(this.permission);

  final Permission permission;

  @override
  String userMessage(AppLocalizations l10n) => l10n.permissionDeniedBody;
}

final class ConnectionTimeoutException extends AppException {
  const ConnectionTimeoutException({required this.timeout});

  final Duration timeout;

  @override
  String userMessage(AppLocalizations l10n) => l10n.connectionTimeout;
}

final class PeerRejectedException extends AppException {
  const PeerRejectedException();

  @override
  String userMessage(AppLocalizations l10n) => l10n.peerRejected;
}

final class WebSocketException extends AppException {
  const WebSocketException(this.originalError);

  final Object originalError;

  @override
  String userMessage(AppLocalizations l10n) => l10n.webSocketDisconnected;
}

final class UnknownAppException extends AppException {
  const UnknownAppException([this.originalError]);

  final Object? originalError;

  @override
  String userMessage(AppLocalizations l10n) => l10n.unknownError;
}
