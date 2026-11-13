
package com.streamia.streamia_player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File
import java.util.concurrent.Executors
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

    private val exportRequestCode = 7319
    private var pendingExport: MethodChannel.Result? = null
    private var pendingExportFile: File? = null
    private val exportExecutor = Executors.newSingleThreadExecutor()

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != exportRequestCode) return

        val callback = pendingExport ?: return
        val file = pendingExportFile

        pendingExport = null
        pendingExportFile = null

        val uri =
            if (resultCode == Activity.RESULT_OK) data?.data
            else null

        if (uri == null || file == null) {
            callback.success(null)
            return
        }

        exportExecutor.execute {
            try {
                val output =
                    contentResolver.openOutputStream(uri, "w")
                        ?: throw IllegalStateException(
                            "Speicherort nicht beschreibbar"
                        )

                output.use { target ->
                    file.inputStream().use { source ->
                        source.copyTo(target, 128 * 1024)
                    }
                }

                runOnUiThread {
                    callback.success(uri.toString())
                }
            } catch (error: Exception) {
                runOnUiThread {
                    callback.error(
                        "EXPORT_FAILED",
                        "Aufnahme konnte nicht gespeichert werden. Original bleibt erhalten.",
                        null
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "getAndroidId" -> result.success(
                    Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                )

                "getDeviceName" -> result.success(
                    "${Build.MANUFACTURER} ${Build.MODEL}".trim()
                )

                else -> result.notImplemented()
            }
        }

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

                        result.success(true)
                    } catch (_: Exception) {
                        result.error(
                            "START_FAILED",
                            "Aufnahmedienst konnte nicht gestartet werden.",
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
                    } catch (_: Exception) {
                        result.error(
                            "STOP_FAILED",
                            "Aufnahme konnte nicht gestoppt werden.",
                            null
                        )
                    }
                }

                "exportRecording" -> {
                    if (pendingExport != null) {
                        result.error(
                            "EXPORT_BUSY",
                            "Eine Dateiauswahl ist bereits geöffnet.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (StreamRecordingService.isRecording) {
                        result.error(
                            "RECORDING_ACTIVE",
                            "Bitte zuerst die Aufnahme stoppen.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val path =
                        StreamRecordingService.outputPath

                    val file = path?.let { File(it) }

                    if (
                        file == null ||
                        !file.isFile ||
                        file.length() == 0L
                    ) {
                        result.error(
                            "NO_RECORDING",
                            "Keine abgeschlossene Aufnahme vorhanden.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val intent =
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(
                                    Intent.CATEGORY_OPENABLE
                                )
                                type = "video/mp2t"

                                putExtra(
                                    Intent.EXTRA_TITLE,
                                    file.name
                                )
                            }

                        pendingExport = result
                        pendingExportFile = file

                        startActivityForResult(
                            intent,
                            exportRequestCode
                        )
                    } catch (error: Exception) {
                        pendingExport = null
                        pendingExportFile = null

                        result.error(
                            "PICKER_UNAVAILABLE",
                            "Dieses Gerät bietet keine unterstützte Dateiauswahl.",
                            null
                        )
                    }
                }

                "getRecordingStatus" -> {
                    val active =
                        StreamRecordingService.isRecording

                    val writing =
                        StreamRecordingService.isWriting

                    val startedAt =
                        StreamRecordingService.startedAt

                    val elapsedMs =
                        if (startedAt > 0L) {
                            (
                                SystemClock.elapsedRealtime() -
                                startedAt
                            ).coerceAtLeast(0L)
                        } else {
                            0L
                        }

                    result.success(
                        mapOf(
                            "active" to active,
                            "writing" to writing,
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
