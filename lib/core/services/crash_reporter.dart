import 'dart:developer' as dev;

abstract class CrashReporter {
  void recordError(Object error, StackTrace? st, {String? reason});
  void log(String message);
}

class LoggerCrashReporter implements CrashReporter {
  const LoggerCrashReporter({this.name = 'CrashReporter'});

  final String name;

  @override
  void recordError(Object error, StackTrace? st, {String? reason}) {
    dev.log(
      reason ?? 'recordError',
      name: name,
      error: error,
      stackTrace: st,
    );
  }

  @override
  void log(String message) {
    dev.log(message, name: name);
  }
}

