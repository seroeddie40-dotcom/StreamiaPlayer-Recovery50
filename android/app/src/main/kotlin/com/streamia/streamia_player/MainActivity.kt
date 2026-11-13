
package com.streamia.streamia_player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.DocumentsContract
import android.provider.OpenableColumns
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

    private val ioExecutor =
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
                        OpenableColumns.DISPLAY_NAME
                    ),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(
                            OpenableColumns.DISPLAY_NAME
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

    private fun folderDocumentUris(): List<Uri> {
        val folderString =
            selectedFolder() ?: return emptyList()

        val treeUri = Uri.parse(folderString)

        val treeDocumentId =
            DocumentsContract.getTreeDocumentId(treeUri)

        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri,
                treeDocumentId
            )

        val documentUris = mutableListOf<Uri>()

        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            ),
            null,
            null,
            null
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID
            )

            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )

            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )

            while (cursor.moveToNext()) {
                val name = cursor.getString(nameIndex) ?: ""
                val mime = cursor.getString(mimeIndex) ?: ""

                if (
                    !name.lowercase().endsWith(".ts") &&
                    mime != "video/mp2t"
                ) {
                    continue
                }

                val documentId = cursor.getString(idIndex)

                documentUris.add(
                    DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        documentId
                    )
                )
            }
        }

        return documentUris
    }

    private fun requireKnownUsbRecording(
        rawUri: String
    ): Uri {
        val requested = Uri.parse(rawUri)

        require(requested.scheme == "content") {
            "Ungültige Aufnahmeadresse."
        }

        val known = folderDocumentUris().firstOrNull {
            it == requested
        }

        return known ?: throw SecurityException(
            "Die Aufnahme gehört nicht zum freigegebenen Aufnahmeordner."
        )
    }

    private fun listUsbRecordings():
        List<Map<String, Any?>> {

        val folderString =
            selectedFolder() ?: return emptyList()

        val treeUri = Uri.parse(folderString)

        val treeDocumentId =
            DocumentsContract.getTreeDocumentId(treeUri)

        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri,
                treeDocumentId
            )

        val recordings =
            mutableListOf<Map<String, Any?>>()

        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED
            ),
            null,
            null,
            null
        )?.use { cursor ->

            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID
            )

            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )

            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )

            val sizeIndex = cursor.getColumnIndex(
                DocumentsContract.Document.COLUMN_SIZE
            )

            val modifiedIndex = cursor.getColumnIndex(
                DocumentsContract.Document.COLUMN_LAST_MODIFIED
            )

            while (cursor.moveToNext()) {
                val name =
                    cursor.getString(nameIndex) ?: ""

                val mime =
                    cursor.getString(mimeIndex) ?: ""

                if (
                    !name.lowercase().endsWith(".ts") &&
                    mime != "video/mp2t"
                ) {
                    continue
                }

                val documentId =
                    cursor.getString(idIndex)

                val documentUri =
                    DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        documentId
                    )

                val size =
                    if (
                        sizeIndex >= 0 &&
                        !cursor.isNull(sizeIndex)
                    ) {
                        cursor.getLong(sizeIndex)
                    } else {
                        0L
                    }

                val modified =
                    if (
                        modifiedIndex >= 0 &&
                        !cursor.isNull(modifiedIndex)
                    ) {
                        cursor.getLong(modifiedIndex)
                    } else {
                        0L
                    }

                recordings.add(
                    mapOf(
                        "name" to name,
                        "uri" to documentUri.toString(),
                        "size" to size,
                        "modified" to modified
                    )
                )
            }
        }

        return recordings
    }

    private fun prepareUsbPlayback(
        rawUri: String
    ): String {
        val sourceUri =
            requireKnownUsbRecording(rawUri)

        if (
            StreamRecordingService.isRecording &&
            StreamRecordingService.outputPath ==
                sourceUri.toString()
        ) {
            throw IllegalStateException(
                "Eine laufende Aufnahme kann noch nicht abgespielt werden."
            )
        }

        val sourceName =
            recordingName(sourceUri, null)

        val safeName = sourceName
            .replace(
                Regex("[^A-Za-z0-9._-]"),
                "_"
            )
            .take(80)
            .ifBlank { "Aufnahme.ts" }

        val cacheDirectory =
            File(cacheDir, "recording_playback")

        require(
            cacheDirectory.exists() ||
                cacheDirectory.mkdirs()
        ) {
            "Wiedergabe-Cache konnte nicht erstellt werden."
        }

        val size = contentResolver.query(
            sourceUri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor ->
            val index = cursor.getColumnIndex(
                OpenableColumns.SIZE
            )

            if (
                cursor.moveToFirst() &&
                index >= 0 &&
                !cursor.isNull(index)
            ) {
                cursor.getLong(index)
            } else {
                -1L
            }
        } ?: -1L

        if (
            size > 0 &&
            size > cacheDirectory.usableSpace
        ) {
            throw IllegalStateException(
                "Nicht genügend freier Gerätespeicher für die Wiedergabe."
            )
        }

        val target = File.createTempFile(
            "streamia_",
            "_$safeName",
            cacheDirectory
        )

        try {
            val input =
                contentResolver.openInputStream(
                    sourceUri
                ) ?: throw IllegalStateException(
                    "USB-Aufnahme konnte nicht geöffnet werden."
                )

            input.use { source ->
                target.outputStream().buffered().use { output ->
                    val buffer = ByteArray(128 * 1024)

                    while (true) {
                        val count = source.read(buffer)

                        if (count < 0) break
                        if (count == 0) continue

                        output.write(
                            buffer,
                            0,
                            count
                        )
                    }

                    output.flush()
                }
            }

            require(target.length() > 0L) {
                "Die Aufnahme enthält keine Daten."
            }

            return target.absolutePath
        } catch (error: Exception) {
            target.delete()
            throw error
        }
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

        ioExecutor.execute {
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
                        "Export fehlgeschlagen. " +
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
                    result.success(selectedFolder())
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
                            "Aufnahme ist nicht mehr lesbar.",
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

                "listUsbRecordings" -> {
                    ioExecutor.execute {
                        try {
                            val recordings =
                                listUsbRecordings()

                            runOnUiThread {
                                result.success(recordings)
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "USB_LIST_FAILED",
                                    error.message
                                        ?: "USB-Aufnahmen konnten nicht gelesen werden.",
                                    null
                                )
                            }
                        }
                    }
                }

                "deleteUsbRecording" -> {
                    val rawUri =
                        call.argument<String>("uri")

                    if (rawUri.isNullOrBlank()) {
                        result.error(
                            "INVALID_URI",
                            "Keine Aufnahme ausgewählt.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    ioExecutor.execute {
                        try {
                            val uri =
                                requireKnownUsbRecording(rawUri)

                            if (
                                StreamRecordingService.isRecording &&
                                StreamRecordingService.outputPath ==
                                    uri.toString()
                            ) {
                                throw IllegalStateException(
                                    "Eine laufende Aufnahme darf nicht gelöscht werden."
                                )
                            }

                            val deleted =
                                DocumentsContract.deleteDocument(
                                    contentResolver,
                                    uri
                                )

                            runOnUiThread {
                                result.success(deleted)
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "USB_DELETE_FAILED",
                                    error.message
                                        ?: "USB-Aufnahme konnte nicht gelöscht werden.",
                                    null
                                )
                            }
                        }
                    }
                }

                "prepareUsbRecordingPlayback" -> {
                    val rawUri =
                        call.argument<String>("uri")

                    if (rawUri.isNullOrBlank()) {
                        result.error(
                            "INVALID_URI",
                            "Keine Aufnahme ausgewählt.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    ioExecutor.execute {
                        try {
                            val path =
                                prepareUsbPlayback(rawUri)

                            runOnUiThread {
                                result.success(path)
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "USB_PLAYBACK_FAILED",
                                    error.message
                                        ?: "USB-Aufnahme konnte nicht geöffnet werden.",
                                    null
                                )
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }
}
