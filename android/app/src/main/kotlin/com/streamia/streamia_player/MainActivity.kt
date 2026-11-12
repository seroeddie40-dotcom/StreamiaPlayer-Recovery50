
package com.streamia.streamia_player

import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val DEVICE_CHANNEL =
            "com.streamia/device_identity"

        private const val RECORDING_CHANNEL =
            "com.streamia/recording"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        // Bestehende Geräteerkennung beibehalten.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "getAndroidId" -> {
                    result.success(
                        Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                    )
                }

                "getDeviceName" -> {
                    result.success(
                        "${Build.MANUFACTURER} ${Build.MODEL}".trim()
                    )
                }

                else -> result.notImplemented()
            }
        }

        // Native Aufnahmeverwaltung.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RECORDING_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startRecording" -> {
                    val streamUrl =
                        call.argument<String>("streamUrl")

                    val channelName =
                        call.argument<String>("channelName")
                            ?: "Live_TV"

                    if (streamUrl.isNullOrBlank()) {
                        result.error(
                            "INVALID_URL",
                            "Keine Stream-Adresse vorhanden.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (StreamRecordingService.isRecording) {
                        result.error(
                            "ALREADY_RECORDING",
                            "Es läuft bereits eine Aufnahme.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val intent = Intent(
                            this,
                            StreamRecordingService::class.java
                        ).apply {
                            action =
                                StreamRecordingService.ACTION_START

                            putExtra(
                                StreamRecordingService.EXTRA_URL,
                                streamUrl
                            )

                            putExtra(
                                StreamRecordingService.EXTRA_NAME,
                                channelName
                            )
                        }

                        if (Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }

                        // Der Dienst wurde angefordert.
                        // Das bedeutet noch NICHT, dass
                        // bereits Videodaten geschrieben werden.
                        result.success(true)

                    } catch (error: Exception) {
                        result.error(
                            "START_FAILED",
                            "Der Aufnahmedienst konnte nicht gestartet werden.",
                            null
                        )
                    }
                }

                "stopRecording" -> {
                    try {
                        val intent = Intent(
                            this,
                            StreamRecordingService::class.java
                        ).apply {
                            action =
                                StreamRecordingService.ACTION_STOP
                        }

                        startService(intent)
                        result.success(true)

                    } catch (error: Exception) {
                        result.error(
                            "STOP_FAILED",
                            "Die Aufnahme konnte nicht gestoppt werden.",
                            null
                        )
                    }
                }

                "getRecordingStatus" -> {
                    val active =
                        StreamRecordingService.isRecording

                    val startedAt =
                        StreamRecordingService.startedAt

                    val elapsedMs =
                        if (active && startedAt > 0L) {
                            SystemClock.elapsedRealtime() -
                                startedAt
                        } else {
                            0L
                        }

                    result.success(
                        mapOf(
                            "active" to active,
                            "bytesWritten" to
                                StreamRecordingService.bytesWritten,
                            "elapsedMs" to elapsedMs,
                            "outputPath" to
                                StreamRecordingService.outputPath,
                            "error" to
                                StreamRecordingService.lastError
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }
}
