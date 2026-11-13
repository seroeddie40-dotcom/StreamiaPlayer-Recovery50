
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

        private const val NOTIFICATION_ID = 2401
        private const val CHANNEL_ID = "streamia_recordings"
        private const val MIME_TS = "video/mp2t"

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

    @Volatile
    private var connection: HttpURLConnection? = null

    @Volatile
    private var worker: Thread? = null

    @Volatile
    private var latestStartId: Int = 0

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
                outputPath = null
                lastError = null

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

    private fun recordingFolderUri(): Uri? {
        val preferences = getSharedPreferences(
            "streamia_recording_storage",
            MODE_PRIVATE
        )

        val stored = preferences.getString(
            "folder_uri",
            null
        ) ?: return null

        val uri = Uri.parse(stored)

        val permissionAvailable =
            contentResolver.persistedUriPermissions.any {
                it.uri == uri && it.isWritePermission
            }

        require(permissionAvailable) {
            "Keine gültige Schreibberechtigung für den Aufnahmeordner."
        }

        return uri
    }

    private fun createRecordingName(
        channelName: String
    ): String {
        val safeName = channelName
            .replace(
                Regex("[^A-Za-z0-9_-]"),
                "_"
            )
            .take(60)
            .ifBlank { "Live_TV" }

        val timestamp = SimpleDateFormat(
            "yyyyMMdd_HHmmss_SSS",
            Locale.US
        ).format(Date())

        return "${safeName}_${timestamp}.ts"
    }

    private data class RecordingTarget(
        val stream: OutputStream,
        val location: String,
        val localFile: File?,
        val documentUri: Uri?
    )

    private fun createRecordingTarget(
        channelName: String
    ): RecordingTarget {
        val fileName =
            createRecordingName(channelName)

        val folderUri = recordingFolderUri()

        if (folderUri != null) {
            val documentUri =
                DocumentsContract.createDocument(
                    contentResolver,
                    folderUri,
                    MIME_TS,
                    fileName
                ) ?: throw IllegalStateException(
                    "Aufnahmedatei konnte auf dem Speichermedium nicht erstellt werden."
                )

            try {
                val stream =
                    contentResolver.openOutputStream(
                        documentUri,
                        "w"
                    ) ?: throw IllegalStateException(
                        "Speichermedium ist nicht beschreibbar."
                    )

                return RecordingTarget(
                    stream = stream.buffered(),
                    location = documentUri.toString(),
                    localFile = null,
                    documentUri = documentUri
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

        val file = File(directory, fileName)

        return RecordingTarget(
            stream = file.outputStream().buffered(),
            location = file.absolutePath,
            localFile = file,
            documentUri = null
        )
    }

    private fun deleteEmptyTarget(
        target: RecordingTarget?
    ) {
        if (target == null) return

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

    private fun recordStream(
        streamUrl: String,
        channelName: String
    ) {
        var target: RecordingTarget? = null

        try {
            val url = URL(streamUrl)

            require(
                url.protocol == "http" ||
                    url.protocol == "https"
            ) {
                "Nur HTTP(S)-Streams werden unterstützt."
            }

            require(
                !url.path.lowercase()
                    .endsWith(".m3u8")
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

                if (stopRequested.get()) return

                target = createRecordingTarget(
                    channelName
                )

                val destination = target!!

                destination.stream.use { output ->
                    if (!stopRequested.get()) {
                        output.write(
                            header,
                            0,
                            received
                        )

                        bytesWritten =
                            received.toLong()

                        startedAt =
                            SystemClock.elapsedRealtime()

                        outputPath =
                            destination.location

                        writing.set(true)

                        val buffer =
                            ByteArray(64 * 1024)

                        while (!stopRequested.get()) {
                            val count =
                                input.read(buffer)

                            if (count < 0) break
                            if (count == 0) continue

                            output.write(
                                buffer,
                                0,
                                count
                            )

                            bytesWritten +=
                                count.toLong()
                        }

                        output.flush()
                    }
                }
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
                        "Kein Schreibzugriff auf den Aufnahmeordner."

                    else ->
                        "Aufnahme durch Netzwerk- oder Speicherfehler beendet: " +
                            (error.message ?: "Unbekannter Fehler")
                }
            }
        } finally {
            writing.set(false)

            connection?.disconnect()
            connection = null

            if (bytesWritten == 0L) {
                deleteEmptyTarget(target)
                outputPath = null
            }
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
