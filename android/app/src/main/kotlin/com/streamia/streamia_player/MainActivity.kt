
package com.streamia.streamia_player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val DEVICE_CHANNEL =
            "com.streamia/device_identity"

        private const val RECORDING_CHANNEL =
            "com.streamia/recording"

        private const val EXPORT_REQUEST = 7319
        private const val FOLDER_REQUEST = 7320

        private const val STORAGE_PREFS =
            "streamia_recording_storage"

        private const val FOLDER_KEY = "folder_uri"
    }

    private val storagePreferences by lazy {
        getSharedPreferences(STORAGE_PREFS, MODE_PRIVATE)
    }

    private val exportExecutor =
        Executors.newSingleThreadExecutor()

    private var pendingExport: MethodChannel.Result? = null
    private var pendingExportSource: Uri? = null
    private var pendingExportFile: File? = null

    private var pendingFolderSelection:
        MethodChannel.Result? = null

    private fun selectedFolder(): String? {
        val stored = storagePreferences.getString(
            FOLDER_KEY,
            null
        ) ?: return null

        val uri = Uri.parse(stored)

        val granted =
            contentResolver.persistedUriPermissions.any {
                it.uri == uri &&
                    it.isReadPermission &&
                    it.isWritePermission
            }

        return if (granted) stored else null
    }

    private fun recordingSource(
        path: String
    ): Pair<Uri?, File?> {
        return if (path.startsWith("content://")) {
            Pair(Uri.parse(path), null)
        } else {
            Pair(null, File(path))
        }
    }

    private fun recordingName(
        uri: Uri?,
        file: File?
    ): String {
        if (file != null) {
            return file.name
        }

        if (uri != null) {
            try {
                contentResolver.query(
                    uri,
                    arrayOf(
                        android.provider.OpenableColumns.DISPLAY_NAME
                    ),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(
                            android.provider.OpenableColumns.DISPLAY_NAME
                        )

                        if (index >= 0) {
                            val name = cursor.getString(index)
                            if (!name.isNullOrBlank()) {
                                return name
                            }
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }

        return "Streamia_Aufnahme.ts"
    }

    private fun sourceAvailable(
        uri: Uri?,
        file: File?
    ): Boolean {
        if (file != null) {
            return file.isFile && file.length() > 0L
        }

        if (uri != null) {
            return try {
                contentResolver.openInputStream(uri)?.use {
                    true
                } ?: false
            } catch (_: Exception) {
                false
            }
        }

        return false
    }

    private fun clearPendingExport() {
        pendingExport = null
        pendingExportSource = null
        pendingExportFile = null
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(
            requestCode,
            resultCode,
            data
        )

        if (requestCode == FOLDER_REQUEST) {
            val callback =
                pendingFolderSelection ?: return

            pendingFolderSelection = null

            val uri =
                if (resultCode == Activity.RESULT_OK) {
                    data?.data
                } else {
                    null
                }

            if (uri == null) {
                callback.success(null)
                return
            }

            try {
                val flags =
                    (data?.flags ?: 0) and (
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )

                require(
                    flags and
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0
                ) {
                    "Kein Schreibzugriff erteilt."
                }

                contentResolver.takePersistableUriPermission(
                    uri,
                    flags
                )

                val previous =
                    storagePreferences.getString(
                        FOLDER_KEY,
                        null
                    )

                storagePreferences.edit()
                    .putString(
                        FOLDER_KEY,
                        uri.toString()
                    )
                    .apply()

                if (
                    previous != null &&
                    previous != uri.toString()
                ) {
                    try {
                        contentResolver.releasePersistableUriPermission(
                            Uri.parse(previous),
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )
                    } catch (_: Exception) {
                    }
                }

                callback.success(uri.toString())
            } catch (error: Exception) {
                callback.error(
                    "FOLDER_PERMISSION_FAILED",
                    error.message
                        ?: "Ordnerfreigabe fehlgeschlagen.",
                    null
                )
            }

            return
        }

        if (requestCode != EXPORT_REQUEST) {
            return
        }

        val callback = pendingExport ?: return
        val sourceUri = pendingExportSource
        val sourceFile = pendingExportFile

        clearPendingExport()

        val destination =
            if (resultCode == Activity.RESULT_OK) {
                data?.data
            } else {
                null
            }

        if (destination == null) {
            callback.success(null)
            return
        }

        if (
            sourceUri != null &&
            sourceUri == destination
        ) {
            callback.success(destination.toString())
            return
        }

        exportExecutor.execute {
            try {
                val input =
                    if (sourceUri != null) {
                        contentResolver.openInputStream(
                            sourceUri
                        )
                    } else {
                        sourceFile?.inputStream()
                    } ?: throw IllegalStateException(
                        "Quelldatei konnte nicht geöffnet werden."
                    )

                val output =
                    contentResolver.openOutputStream(
                        destination,
                        "w"
                    ) ?: throw IllegalStateException(
                        "Zieldatei konnte nicht geöffnet werden."
                    )

                input.use { source ->
                    output.use { target ->
                        source.copyTo(
                            target,
                            128 * 1024
                        )
                        target.flush()
                    }
                }

                runOnUiThread {
                    callback.success(
                        destination.toString()
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    callback.error(
                        "EXPORT_FAILED",
                        "Aufnahme konnte nicht exportiert werden. " +
                            "Die Originalaufnahme bleibt erhalten. " +
                            (error.message ?: ""),
                        null
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

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
                        "${Build.MANUFACTURER} ${Build.MODEL}"
                            .trim()
                    )
                }

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
                        call.argument<String>(
                            "streamUrl"
                        )

                    val channelName =
                        call.argument<String>(
                            "channelName"
                        ) ?: "Live_TV"

                    if (streamUrl.isNullOrBlank()) {
                        result.error(
                            "INVALID_URL",
                            "Keine Stream-Adresse vorhanden.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (
                        StreamRecordingService.isRecording
                    ) {
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

                        if (
                            Build.VERSION.SDK_INT >= 26
                        ) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }

                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "START_FAILED",
                            error.message
                                ?: "Aufnahmestart fehlgeschlagen.",
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
                            error.message
                                ?: "Aufnahmestopp fehlgeschlagen.",
                            null
                        )
                    }
                }

                "getRecordingStatus" -> {
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
                            "active" to
                                StreamRecordingService.isRecording,
                            "writing" to
                                StreamRecordingService.isWriting,
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

                "chooseRecordingFolder" -> {
                    if (
                        pendingFolderSelection != null ||
                        pendingExport != null
                    ) {
                        result.error(
                            "PICKER_BUSY",
                            "Eine Speicherauswahl ist bereits geöffnet.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val intent = Intent(
                            Intent.ACTION_OPEN_DOCUMENT_TREE
                        ).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }

                        pendingFolderSelection = result

                        startActivityForResult(
                            intent,
                            FOLDER_REQUEST
                        )
                    } catch (error: Exception) {
                        pendingFolderSelection = null

                        result.error(
                            "PICKER_UNAVAILABLE",
                            error.message
                                ?: "Ordnerauswahl nicht verfügbar.",
                            null
                        )
                    }
                }

                "getRecordingFolder" -> {
                    result.success(
                        selectedFolder()
                    )
                }

                "clearRecordingFolder" -> {
                    val previous =
                        storagePreferences.getString(
                            FOLDER_KEY,
                            null
                        )

                    storagePreferences.edit()
                        .remove(FOLDER_KEY)
                        .apply()

                    if (previous != null) {
                        try {
                            contentResolver.releasePersistableUriPermission(
                                Uri.parse(previous),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            )
                        } catch (_: Exception) {
                        }
                    }

                    result.success(true)
                }

                "exportRecording" -> {
                    if (
                        pendingExport != null ||
                        pendingFolderSelection != null
                    ) {
                        result.error(
                            "PICKER_BUSY",
                            "Eine Dateiauswahl ist bereits geöffnet.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (
                        StreamRecordingService.isRecording
                    ) {
                        result.error(
                            "RECORDING_ACTIVE",
                            "Bitte zuerst die Aufnahme stoppen.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val path =
                        StreamRecordingService.outputPath

                    if (path.isNullOrBlank()) {
                        result.error(
                            "NO_RECORDING",
                            "Keine abgeschlossene Aufnahme vorhanden.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val (sourceUri, sourceFile) =
                        recordingSource(path)

                    if (
                        !sourceAvailable(
                            sourceUri,
                            sourceFile
                        )
                    ) {
                        result.error(
                            "SOURCE_UNAVAILABLE",
                            "Die Aufnahme ist nicht mehr lesbar. " +
                                "Bitte Speichermedium prüfen.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val fileName =
                            recordingName(
                                sourceUri,
                                sourceFile
                            )

                        val intent = Intent(
                            Intent.ACTION_CREATE_DOCUMENT
                        ).apply {
                            addCategory(
                                Intent.CATEGORY_OPENABLE
                            )

                            type = "video/mp2t"

                            putExtra(
                                Intent.EXTRA_TITLE,
                                fileName
                            )
                        }

                        pendingExport = result
                        pendingExportSource = sourceUri
                        pendingExportFile = sourceFile

                        startActivityForResult(
                            intent,
                            EXPORT_REQUEST
                        )
                    } catch (error: Exception) {
                        clearPendingExport()

                        result.error(
                            "PICKER_UNAVAILABLE",
                            error.message
                                ?: "Dateiauswahl nicht verfügbar.",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        exportExecutor.shutdown()
        super.onDestroy()
    }
}
