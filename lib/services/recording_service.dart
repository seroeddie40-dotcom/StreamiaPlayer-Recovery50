
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RecordingPhase {
  idle,
  starting,
  recording,
  stopping,
  failed,
}

class RecordingStatus {
  final RecordingPhase phase;
  final bool active;
  final bool writing;
  final int bytesWritten;
  final Duration elapsed;
  final String? outputPath;
  final String? error;

  const RecordingStatus({
    required this.phase,
    required this.active,
    required this.writing,
    required this.bytesWritten,
    required this.elapsed,
    this.outputPath,
    this.error,
  });

  bool get isRecording =>
      phase == RecordingPhase.recording;

  bool get isBusy =>
      active ||
      phase == RecordingPhase.starting ||
      phase == RecordingPhase.stopping;
}

class RecordingService {
  static const MethodChannel _channel =
      MethodChannel('com.streamia/recording');

  static const Duration _startLimit =
      Duration(seconds: 50);

  static const Duration _stopLimit =
      Duration(seconds: 40);

  static final ValueNotifier<RecordingStatus> status =
      ValueNotifier<RecordingStatus>(
    const RecordingStatus(
      phase: RecordingPhase.idle,
      active: false,
      writing: false,
      bytesWritten: 0,
      elapsed: Duration.zero,
    ),
  );

  static Timer? _statusTimer;
  static DateTime? _startRequestedAt;
  static DateTime? _stopRequestedAt;

  static bool _requestInProgress = false;
  static bool _pollInProgress = false;
  static bool _awaitingNativeStart = false;
  static bool _stopSent = false;

  static bool get isActive => status.value.isBusy;

  static Future<bool> start(
    String channelName, {
    required String streamUrl,
  }) async {
    if (_requestInProgress || status.value.isBusy) {
      return false;
    }

    await refreshStatus();

    if (_requestInProgress || status.value.isBusy) {
      return false;
    }

    if (streamUrl.trim().isEmpty) {
      _setFailure('Keine Stream-Adresse vorhanden.');
      return false;
    }

    _requestInProgress = true;
    _awaitingNativeStart = true;
    _stopSent = false;
    _stopRequestedAt = null;
    _startRequestedAt = DateTime.now();

    status.value = const RecordingStatus(
      phase: RecordingPhase.starting,
      active: true,
      writing: false,
      bytesWritten: 0,
      elapsed: Duration.zero,
    );

    try {
      final accepted = await _channel.invokeMethod<bool>(
        'startRecording',
        {
          'streamUrl': streamUrl,
          'channelName': channelName,
        },
      );

      if (accepted != true) {
        _awaitingNativeStart = false;
        _startRequestedAt = null;

        _setFailure(
          'Android hat den Aufnahmestart abgelehnt.',
        );

        return false;
      }

      _startMonitoring();
      return true;
    } on PlatformException catch (error) {
      _awaitingNativeStart = false;
      _startRequestedAt = null;

      if (error.code == 'ALREADY_RECORDING') {
        await refreshStatus();
      } else {
        _setFailure(
          'Der Aufnahmedienst konnte nicht gestartet werden.',
        );
      }

      return false;
    } on MissingPluginException {
      _awaitingNativeStart = false;
      _startRequestedAt = null;

      _setFailure(
        'Die native Aufnahmefunktion ist nicht verfügbar.',
      );

      return false;
    } catch (_) {
      _awaitingNativeStart = false;
      _startRequestedAt = null;

      _setFailure(
        'Aufnahme konnte nicht gestartet werden.',
      );

      return false;
    } finally {
      _requestInProgress = false;
    }
  }

  static Future<void> stop() async {
    if (_requestInProgress || _stopSent) {
      return;
    }

    _requestInProgress = true;
    _stopSent = true;
    _awaitingNativeStart = false;
    _startRequestedAt = null;
    _stopRequestedAt = DateTime.now();

    final previous = status.value;

    status.value = RecordingStatus(
      phase: RecordingPhase.stopping,
      active: true,
      writing: previous.writing,
      bytesWritten: previous.bytesWritten,
      elapsed: previous.elapsed,
      outputPath: previous.outputPath,
    );

    try {
      final accepted =
          await _channel.invokeMethod<bool>(
        'stopRecording',
      );

      if (accepted != true) {
        _stopSent = false;
        _stopRequestedAt = null;

        _setFailure(
          'Android hat den Aufnahmestopp abgelehnt.',
        );

        return;
      }

      _startMonitoring();
    } catch (_) {
      _stopSent = false;
      _stopRequestedAt = null;

      _setFailure(
        'Aufnahme konnte nicht gestoppt werden.',
      );
    } finally {
      _requestInProgress = false;
    }
  }

  static Future<RecordingStatus> refreshStatus() async {
    if (_pollInProgress) {
      return status.value;
    }

    _pollInProgress = true;

    try {
      final raw =
          await _channel.invokeMapMethod<String, dynamic>(
        'getRecordingStatus',
      );

      if (raw == null) {
        return status.value;
      }

      final nativeActive = raw['active'] == true;
      final writing = raw['writing'] == true;

      final bytes =
          (raw['bytesWritten'] as num?)?.toInt() ?? 0;

      final elapsedMs =
          (raw['elapsedMs'] as num?)?.toInt() ?? 0;

      final path = raw['outputPath'] as String?;
      final error = raw['error'] as String?;

      final previous = status.value;
      final now = DateTime.now();

      if (_awaitingNativeStart && nativeActive) {
        _awaitingNativeStart = false;
      }

      if (writing) {
        _startRequestedAt = null;
      }

      final startTimedOut =
          _startRequestedAt != null &&
          now.difference(_startRequestedAt!) >=
              _startLimit &&
          !writing &&
          !_stopSent;

      if (startTimedOut) {
        _awaitingNativeStart = false;
        _startRequestedAt = null;

        if (!_requestInProgress) {
          unawaited(stop());
        }
      }

      final stopTimedOut =
          _stopSent &&
          _stopRequestedAt != null &&
          now.difference(_stopRequestedAt!) >=
              _stopLimit;

      RecordingPhase phase;
      String? displayedError = error;

      bool active =
          nativeActive || _awaitingNativeStart;

      if (stopTimedOut) {
        phase = RecordingPhase.failed;

        displayedError =
            'Aufnahmestopp dauert zu lange. '
            'Bitte Android prüfen.';

        active = nativeActive;
        _stopSent = false;
        _stopRequestedAt = null;
      } else if (_stopSent) {
        if (nativeActive) {
          phase = RecordingPhase.stopping;
          active = true;
        } else {
          phase =
              (error != null && error.isNotEmpty)
                  ? RecordingPhase.failed
                  : RecordingPhase.idle;

          _stopSent = false;
          _stopRequestedAt = null;
          active = false;
        }
      } else if (nativeActive) {
        phase = writing
            ? RecordingPhase.recording
            : RecordingPhase.starting;
      } else if (_awaitingNativeStart) {
        phase = RecordingPhase.starting;
      } else if (error != null && error.isNotEmpty) {
        phase = RecordingPhase.failed;
      } else {
        phase = RecordingPhase.idle;
      }

      if (previous.phase == RecordingPhase.failed &&
          !nativeActive &&
          !writing &&
          displayedError == null) {
        phase = RecordingPhase.failed;
        displayedError = previous.error;
      }

      final updated = RecordingStatus(
        phase: phase,
        active: active,
        writing: writing,
        bytesWritten: bytes,
        elapsed: Duration(
          milliseconds: elapsedMs < 0 ? 0 : elapsedMs,
        ),
        outputPath: path,
        error: displayedError,
      );

      status.value = updated;

      if (!updated.isBusy) {
        _statusTimer?.cancel();
        _statusTimer = null;
      }

      return updated;
    } catch (_) {
      return status.value;
    } finally {
      _pollInProgress = false;
    }
  }

  /// Opens the Android export picker for the last completed
  /// recording. Waits for the native recording service to
  /// finish before requesting access to its output.
  ///
  /// Returns the exported document URI, or null if the
  /// user cancels the Android picker.
  static Future<String?> exportLastRecording() async {
    const waitInterval = Duration(milliseconds: 400);
    const maxWait = Duration(seconds: 45);

    final deadline = DateTime.now().add(maxWait);

    RecordingStatus current = await refreshStatus();

    while (current.isBusy &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(waitInterval);
      current = await refreshStatus();
    }

    if (current.isBusy) {
      throw StateError(
        'Die Aufnahme wird noch beendet. '
        'Bitte warten und erneut versuchen.',
      );
    }

    final path = current.outputPath;

    if (path == null || path.trim().isEmpty) {
      throw StateError(
        'Keine abgeschlossene Aufnahme vorhanden.',
      );
    }

    try {
      return await _channel.invokeMethod<String>(
        'exportRecording',
      );
    } on MissingPluginException {
      throw StateError(
        'Die Android-Exportfunktion ist nicht verfügbar.',
      );
    } on PlatformException catch (error) {
      throw StateError(
        error.message ??
            'Die Aufnahme konnte nicht exportiert werden.',
      );
    }
  }

  static void _startMonitoring() {
    _statusTimer?.cancel();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refreshStatus()),
    );
  }

  static void _setFailure(String message) {
    _statusTimer?.cancel();
    _statusTimer = null;

    final previous = status.value;

    status.value = RecordingStatus(
      phase: RecordingPhase.failed,
      active: false,
      writing: false,
      bytesWritten: previous.bytesWritten,
      elapsed: previous.elapsed,
      outputPath: previous.outputPath,
      error: message,
    );
  }

  static void disposeMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }
}
