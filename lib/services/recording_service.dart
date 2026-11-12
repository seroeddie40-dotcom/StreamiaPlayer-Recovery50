
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
  static bool _requestInProgress = false;

  static bool get isActive => status.value.isBusy;

  static Future<bool> start(
    String channelName, {
    required String streamUrl,
  }) async {
    if (_requestInProgress || status.value.isBusy) {
      return false;
    }

    if (streamUrl.trim().isEmpty) {
      _setFailure('Keine Stream-Adresse vorhanden.');
      return false;
    }

    _requestInProgress = true;

    status.value = const RecordingStatus(
      phase: RecordingPhase.starting,
      active: true,
      writing: false,
      bytesWritten: 0,
      elapsed: Duration.zero,
    );

    try {
      await _channel.invokeMethod<bool>(
        'startRecording',
        {
          'streamUrl': streamUrl,
          'channelName': channelName,
        },
      );

      _startMonitoring();

      // Die native Startanforderung ist noch kein
      // Beweis für eine laufende Aufnahme.
      await refreshStatus();

      return true;
    } on PlatformException {
      _setFailure(
        'Der Android-Aufnahmedienst konnte nicht gestartet werden.',
      );
      return false;
    } on MissingPluginException {
      _setFailure(
        'Die native Aufnahmefunktion ist nicht verfügbar.',
      );
      return false;
    } catch (_) {
      _setFailure('Aufnahme konnte nicht gestartet werden.');
      return false;
    } finally {
      _requestInProgress = false;
    }
  }

  static Future<void> stop() async {
    if (_requestInProgress) return;

    _requestInProgress = true;

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
      await _channel.invokeMethod<bool>('stopRecording');

      // Nicht sofort auf idle setzen:
      // Der native Thread muss erst die Datei schließen.
      _startMonitoring();
      await refreshStatus();
    } catch (_) {
      _setFailure('Aufnahme konnte nicht gestoppt werden.');
    } finally {
      _requestInProgress = false;
    }
  }

  static Future<RecordingStatus> refreshStatus() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getRecordingStatus',
      );

      if (raw == null) return status.value;

      final active = raw['active'] == true;
      final bytes =
          (raw['bytesWritten'] as num?)?.toInt() ?? 0;
      final elapsedMs =
          (raw['elapsedMs'] as num?)?.toInt() ?? 0;

      final path = raw['outputPath'] as String?;
      final error = raw['error'] as String?;

      // Bis zur Anpassung der nativen Schnittstelle
      // gilt: Daten geschrieben = Aufnahme bestätigt.
      final writing = active && bytes > 0;

      final previousPhase = status.value.phase;

      RecordingPhase phase;

      if (active) {
        if (previousPhase == RecordingPhase.stopping) {
          phase = RecordingPhase.stopping;
        } else if (writing) {
          phase = RecordingPhase.recording;
        } else {
          phase = RecordingPhase.starting;
        }
      } else if (error != null && error.isNotEmpty) {
        phase = RecordingPhase.failed;
      } else {
        phase = RecordingPhase.idle;
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
        error: error,
      );

      status.value = updated;

      if (!active) {
        _statusTimer?.cancel();
        _statusTimer = null;
      }

      return updated;
    } catch (_) {
      return status.value;
    }
  }

  static void _startMonitoring() {
    _statusTimer?.cancel();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshStatus(),
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
