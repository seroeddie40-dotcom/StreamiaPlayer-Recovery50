
package com.streamia.streamia_player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.content.ContentResolver
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

    private val folderRequestCode = 7320
    private val storagePreferences by lazy {
        getSharedPreferences("streamia_recording_storage", MODE_PRIVATE)
    }
    private var pendingFolderSelection: MethodChannel.Result? = null

    private fun selectedFolder(): String? {
        val stored = storagePreferences.getString("folder_uri", null) ?: return null
        val uri = Uri.parse(stored)
        val granted = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        return if (granted) stored else null
    }

    private val exportRequestCode = 7319
    private var pendingExport: MethodChannel.Result? = null
    private var pendingExportFile: File? = null
    private val exportExecutor = Executors.newSingleThreadExecutor()

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == folderRequestCode) {
            val callback = pendingFolderSelection ?: return
            pendingFolderSelection = null
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                callback.success(null)
                return
            }
            try {
                val flags = (data?.flags ?: 0) and (
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                require(flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0) {
                    "Kein Schreibzugriff erteilt"
                }
                contentResolver.takePersistableUriPermission(uri, flags)
                val previous = storagePreferences.getString("folder_uri", null)
                storagePreferences.edit().putString("folder_uri", uri.toString()).apply()
                if (previous != null && previous != uri.toString()) {
                    try {
                        contentResolver.releasePersistableUriPermission(
                            Uri.parse(previous),
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )
                    } catch (_: Exception) { }
                }
                callback.success(uri.toString())
            } catch (_: Exception) {
                callback.error(
                    "FOLDER_PERMISSION_FAILED",
                    "Ordner konnte nicht dauerhaft freigegeben werden.",
                    null
                )
            }
            return
        }
        if (requestCode != exportRequestCode) return
        val callback = pendingExport ?: return
        val file = pendingExportFile
        pendingExport = null
        pendingExportFile = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null || file == null) {
            callback.success(null)
            return
        }
        exportExecutor.execute {
            try {
                val output = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("Speicherort nicht beschreibbar")
                output.use { target ->
                    file.inputStream().use { source ->
                        source.copyTo(target, 128 * 1024)
                    }
                }
                runOnUiThread { callback.success(uri.toString()) }
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
                            action = StreamRecordingService.ACTION_START
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
                            action = StreamRecordingService.ACTION_STOP
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
                    val path = StreamRecordingService.outputPath
                    val file = path?.let { File(it) }
                    if (file == null || !file.isFile || file.length() == 0L) {
                        result.error(
                            "NO_RECORDING",
                            "Keine abgeschlossene Aufnahme vorhanden.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "video/mp2t"
                            putExtra(Intent.EXTRA_TITLE, file.name)
                        }
                        pendingExport = result
                        pendingExportFile = file
                        startActivityForResult(intent, exportRequestCode)
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

                "chooseRecordingFolder" -> {
                    if (pendingFolderSelection != null || pendingExport != null) {
                        result.error(
                            "PICKER_BUSY",
                            "Es ist bereits eine Speicherauswahl geöffnet.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }
                        pendingFolderSelection = result
                        startActivityForResult(intent, folderRequestCode)
                    } catch (_: Exception) {
                        pendingFolderSelection = null
                        result.error(
                            "PICKER_UNAVAILABLE",
                            "Dieses Gerät unterstützt keine Ordnerauswahl.",
                            null
                        )
                    }
                }

                "getRecordingFolder" -> result.success(selectedFolder())

                "clearRecordingFolder" -> {
                    val previous =
                        storagePreferences.getString("folder_uri", null)
                    storagePreferences.edit().remove("folder_uri").apply()
                    if (previous != null) {
                        try {
                            contentResolver.releasePersistableUriPermission(
                                Uri.parse(previous),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            )
                        } catch (_: Exception) { }
                    }
                    result.success(true)
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
                            (SystemClock.elapsedRealtime() - startedAt)
                                .coerceAtLeast(0L)
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
