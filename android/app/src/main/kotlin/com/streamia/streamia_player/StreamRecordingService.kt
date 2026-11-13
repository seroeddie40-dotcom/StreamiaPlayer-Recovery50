
package com.streamia.streamia_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.provider.DocumentsContract
import java.io.File
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class StreamRecordingService : Service() {

    companion object {
        const val ACTION_START = "com.streamia.recording.START"
        const val ACTION_STOP = "com.streamia.recording.STOP"
        const val EXTRA_URL = "streamUrl"
        const val EXTRA_NAME = "channelName"

        private const val CHANNEL_ID = "streamia_recordings"
        private const val NOTIFICATION_ID = 2401
        private const val MIME_TS = "video/mp2t"

        // 3.8 GiB per file, below the FAT32 4 GiB limit.
        private const val MAX_PART_BYTES =
            3_800L * 1024L * 1024L

        // Reserve 128 MiB for local app storage.
        private const val LOCAL_RESERVE_BYTES =
            128L * 1024L * 1024L

        private const val BUFFER_SIZE = 64 * 1024

        private val busy = AtomicBoolean(false)
        private val writing = AtomicBoolean(false)
        private val stopRequested = AtomicBoolean(false)

        @Volatile
        var bytesWritten: Long = 0L
            private set

        @Volatile
        var startedAt: Long = 0L
            private set

        @Volatile
        var lastError: String? = null
            private set

        @Volatile
        var outputPath: String? = null
            private set

        val isRecording: Boolean
            get() = busy.get()

        val isWriting: Boolean
            get() = writing.get()
    }

    private data class RecordingTarget(
        val output: OutputStream,
        val location: String,
        val localFile: File?,
        val documentUri: Uri?,
        val localDirectory: File?
    )

    @Volatile
    private var connection: HttpURLConnection? = null

    @Volatile
    private var worker: Thread? = null

    @Volatile
    private var latestStartId = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        latestStartId = startId

        when (intent?.action) {

            ACTION_STOP -> {
                stopRequested.set(true)
                connection?.disconnect()
                worker?.interrupt()

                if (!busy.get()) {
                    stopSelfResult(startId)
                }

                return START_NOT_STICKY
            }

            ACTION_START -> {
                if (!busy.compareAndSet(false, true)) {
                    return START_NOT_STICKY
                }

                val streamUrl =
                    intent.getStringExtra(EXTRA_URL)

                val channelName =
                    intent.getStringExtra(EXTRA_NAME)
                        ?: "Live_TV"

                stopRequested.set(false)
                writing.set(false)
                bytesWritten = 0L
                startedAt = 0L
                lastError = null
                outputPath = null

                if (streamUrl.isNullOrBlank()) {
                    lastError =
                        "Keine Stream-Adresse vorhanden."
                    busy.set(false)
                    stopSelfResult(startId)
                    return START_NOT_STICKY
                }

                try {
                    startForeground(
                        NOTIFICATION_ID,
                        buildNotification(channelName)
                    )
                } catch (_: Exception) {
                    lastError =
                        "Aufnahmedienst konnte nicht gestartet werden."
                    busy.set(false)
                    stopSelfResult(startId)
                    return START_NOT_STICKY
                }

                val thread = Thread {
                    try {
                        recordStream(
                            streamUrl,
                            channelName
                        )
                    } finally {
                        writing.set(false)
                        busy.set(false)
                        worker = null
                        stopSelfResult(latestStartId)
                    }
                }

                thread.name = "StreamiaRecorder"
                worker = thread
                thread.start()

                return START_NOT_STICKY
            }
        }

        return START_NOT_STICKY
    }

    private fun selectedRecordingFolder(): Uri? {
        val preferences = getSharedPreferences(
            "streamia_recording_storage",
            MODE_PRIVATE
        )

        val stored = preferences.getString(
            "folder_uri",
            null
        ) ?: return null

        val uri = Uri.parse(stored)

        val permitted =
            contentResolver.persistedUriPermissions.any {
                it.uri == uri &&
                    it.isWritePermission
            }

        require(permitted) {
            "Schreibberechtigung für den Aufnahmeordner fehlt."
        }

        return uri
    }

    private fun safeChannelName(
        channelName: String
    ): String {
        return channelName
            .replace(
                Regex("[^A-Za-z0-9_-]"),
                "_"
            )
            .take(60)
            .ifBlank { "Live_TV" }
    }

    private fun recordingBaseName(
        channelName: String
    ): String {
        val timestamp = SimpleDateFormat(
            "yyyyMMdd_HHmmss_SSS",
            Locale.US
        ).format(Date())

        return "${safeChannelName(channelName)}_$timestamp"
    }

    private fun createTarget(
        baseName: String,
        partNumber: Int,
        folderUri: Uri?
    ): RecordingTarget {
        val part = partNumber
            .toString()
            .padStart(3, '0')

        val fileName =
            "${baseName}_part${part}.ts"

        if (folderUri != null) {
            val documentUri =
                DocumentsContract.createDocument(
                    contentResolver,
                    folderUri,
                    MIME_TS,
                    fileName
                ) ?: throw IllegalStateException(
                    "Aufnahmedatei konnte nicht erstellt werden."
                )

            try {
                val output =
                    contentResolver.openOutputStream(
                        documentUri,
                        "w"
                    ) ?: throw IllegalStateException(
                        "Aufnahmeordner ist nicht beschreibbar."
                    )

                return RecordingTarget(
                    output = output.buffered(),
                    location = documentUri.toString(),
                    localFile = null,
                    documentUri = documentUri,
                    localDirectory = null
                )
            } catch (error: Exception) {
                try {
                    DocumentsContract.deleteDocument(
                        contentResolver,
                        documentUri
                    )
                } catch (_: Exception) {
                }

                throw error
            }
        }

        val directory = File(
            getExternalFilesDir(null) ?: filesDir,
            "recordings"
        )

        require(
            directory.exists() || directory.mkdirs()
        ) {
            "Lokaler Aufnahmeordner konnte nicht erstellt werden."
        }

        require(
            directory.usableSpace > LOCAL_RESERVE_BYTES
        ) {
            "Nicht genügend freier Gerätespeicher."
        }

        val file = File(directory, fileName)

        return RecordingTarget(
            output = file.outputStream().buffered(),
            location = file.absolutePath,
            localFile = file,
            documentUri = null,
            localDirectory = directory
        )
    }

    private fun deleteEmptyTarget(
        target: RecordingTarget
    ) {
        try {
            if (target.localFile != null) {
                target.localFile.delete()
            } else if (target.documentUri != null) {
                DocumentsContract.deleteDocument(
                    contentResolver,
                    target.documentUri
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun verifyLocalSpace(
        target: RecordingTarget
    ) {
        val directory =
            target.localDirectory ?: return

        if (
            directory.usableSpace <=
            LOCAL_RESERVE_BYTES
        ) {
            throw IllegalStateException(
                "Aufnahme gestoppt: Gerätespeicher fast voll."
            )
        }
    }

    private fun recordStream(
        streamUrl: String,
        channelName: String
    ) {
        var target: RecordingTarget? = null
        var partBytes = 0L
        var partNumber = 0

        try {
            val url = URL(streamUrl)

            require(
                url.protocol == "http" ||
                    url.protocol == "https"
            ) {
                "Nur HTTP(S)-Streams werden unterstützt."
            }

            require(
                !url.path.lowercase().endsWith(".m3u8")
            ) {
                "HLS-Aufnahmen werden noch nicht unterstützt."
            }

            if (stopRequested.get()) return

            val http =
                url.openConnection() as HttpURLConnection

            connection = http
            http.connectTimeout = 15000
            http.readTimeout = 30000
            http.instanceFollowRedirects = true

            http.setRequestProperty(
                "User-Agent",
                "StreamiaPlayer/1.0"
            )

            http.connect()

            if (stopRequested.get()) return

            require(
                http.responseCode in 200..299
            ) {
                "Der Stream konnte nicht geöffnet werden."
            }

            val contentType =
                http.contentType?.lowercase() ?: ""

            require(
                !contentType.contains("mpegurl") &&
                    !contentType.contains(
                        "application/vnd.apple"
                    )
            ) {
                "HLS-Playlists werden noch nicht unterstützt."
            }

            val folderUri =
                selectedRecordingFolder()

            val baseName =
                recordingBaseName(channelName)

            http.inputStream.use { input ->

                val header = ByteArray(188 * 3)
                var received = 0

                while (
                    received < header.size &&
                    !stopRequested.get()
                ) {
                    val count = input.read(
                        header,
                        received,
                        header.size - received
                    )

                    if (count < 0) break
                    if (count == 0) continue

                    received += count
                }

                if (stopRequested.get()) return

                require(received >= 188 * 2) {
                    "Zu wenige Streamdaten empfangen."
                }

                require(
                    header[0] == 0x47.toByte() &&
                        header[188] == 0x47.toByte()
                ) {
                    "Kein direktes MPEG-TS-Format erkannt."
                }

                val buffer = ByteArray(BUFFER_SIZE)

                fun openNextPart() {
                    if (stopRequested.get()) return

                    partNumber++

                    target = createTarget(
                        baseName,
                        partNumber,
                        folderUri
                    )

                    partBytes = 0L
                }

                fun writeData(
                    source: ByteArray,
                    offset: Int,
                    length: Int
                ) {
                    var position = offset
                    var remaining = length

                    while (
                        remaining > 0 &&
                        !stopRequested.get()
                    ) {
                        if (target == null) {
                            openNextPart()
                        }

                        val current =
                            target ?: break

                        if (
                            partBytes >= MAX_PART_BYTES
                        ) {
                            current.output.flush()
                            current.output.close()

                            target = null
                            openNextPart()
                            continue
                        }

                        verifyLocalSpace(current)

                        val available =
                            MAX_PART_BYTES - partBytes

                        val writeCount = minOf(
                            remaining.toLong(),
                            available
                        ).toInt()

                        current.output.write(
                            source,
                            position,
                            writeCount
                        )

                        partBytes +=
                            writeCount.toLong()

                        bytesWritten +=
                            writeCount.toLong()

                        if (startedAt == 0L) {
                            startedAt =
                                SystemClock.elapsedRealtime()
                        }

                        outputPath =
                            current.location

                        writing.set(true)

                        position += writeCount
                        remaining -= writeCount
                    }
                }

                writeData(
                    header,
                    0,
                    received
                )

                while (!stopRequested.get()) {
                    val count = input.read(buffer)

                    if (count < 0) break
                    if (count == 0) continue

                    writeData(
                        buffer,
                        0,
                        count
                    )
                }

                target?.output?.flush()
            }

            if (!stopRequested.get()) {
                lastError =
                    "Der Stream wurde beendet."
            }

        } catch (error: Exception) {
            if (!stopRequested.get()) {
                lastError = when (error) {
                    is IllegalArgumentException ->
                        error.message
                            ?: "Streamformat nicht unterstützt."

                    is SecurityException ->
                        "Keine Berechtigung für den Aufnahmeordner."

                    is IllegalStateException ->
                        error.message
                            ?: "Aufnahme konnte nicht fortgesetzt werden."

                    else ->
                        "Aufnahme durch Netzwerk- oder Speicherfehler beendet: " +
                            (error.message
                                ?: "Unbekannter Fehler")
                }
            }
        } finally {
            writing.set(false)

            try {
                target?.output?.close()
            } catch (error: Exception) {
                if (!stopRequested.get() &&
                    lastError == null
                ) {
                    lastError =
                        "Aufnahmedatei konnte nicht vollständig geschlossen werden."
                }
            }

            if (partBytes == 0L) {
                target?.let {
                    deleteEmptyTarget(it)
                }
            }

            connection?.disconnect()
            connection = null
        }
    }

    private fun createNotificationChannel() {
        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Streamia Aufnahmen",
                NotificationManager.IMPORTANCE_LOW
            )

            channel.description =
                "Status laufender Live-TV-Aufnahmen"

            getSystemService(
                NotificationManager::class.java
            ).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(
        channelName: String
    ): Notification {
        val stopIntent = Intent(
            this,
            StreamRecordingService::class.java
        ).apply {
            action = ACTION_STOP
        }

        val pendingFlags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                (
                    if (Build.VERSION.SDK_INT >= 23) {
                        PendingIntent.FLAG_IMMUTABLE
                    } else {
                        0
                    }
                )

        val stopPendingIntent =
            PendingIntent.getService(
                this,
                0,
                stopIntent,
                pendingFlags
            )

        val builder =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {
                Notification.Builder(
                    this,
                    CHANNEL_ID
                )
            } else {
                Notification.Builder(this)
            }

        return builder
            .setContentTitle("Streamia Player")
            .setContentText(
                "Live-TV-Aufnahme: $channelName"
            )
            .setSmallIcon(
                android.R.drawable.ic_media_play
            )
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Aufnahme stoppen",
                stopPendingIntent
            )
            .build()
    }

    override fun onDestroy() {
        stopRequested.set(true)
        connection?.disconnect()
        worker?.interrupt()

        super.onDestroy()
    }
}
