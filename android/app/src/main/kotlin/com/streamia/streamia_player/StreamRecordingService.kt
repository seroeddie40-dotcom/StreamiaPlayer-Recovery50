package com.streamia.streamia_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

class StreamRecordingService : Service() {

    companion object {
        const val ACTION_START = "com.streamia.recording.START"
        const val ACTION_STOP = "com.streamia.recording.STOP"
        const val EXTRA_URL = "streamUrl"
        const val EXTRA_NAME = "channelName"

        private const val NOTIFICATION_ID = 2401
        private const val CHANNEL_ID = "streamia_recordings"

        private val busy = AtomicBoolean(false)
        private val writing = AtomicBoolean(false)
        private val stopRequested = AtomicBoolean(false)

        @Volatile var bytesWritten: Long = 0L
            private set
        @Volatile var startedAt: Long = 0L
            private set
        @Volatile var lastError: String? = null
            private set
        @Volatile var outputPath: String? = null
            private set

        val isRecording: Boolean get() = busy.get()
        val isWriting: Boolean get() = writing.get()
    }

    @Volatile private var connection: HttpURLConnection? = null
    @Volatile private var worker: Thread? = null
    @Volatile private var latestStartId: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStartId = startId
        when (intent?.action) {
            ACTION_STOP -> {
                stopRequested.set(true)
                connection?.disconnect()
                worker?.interrupt()
                if (!busy.get()) stopSelfResult(startId)
                return START_NOT_STICKY
            }
            ACTION_START -> {
                if (!busy.compareAndSet(false, true)) {
                    // A duplicate start must never stop the existing recording.
                    return START_NOT_STICKY
                }

                val url = intent.getStringExtra(EXTRA_URL)
                val channelName = intent.getStringExtra(EXTRA_NAME) ?: "Live_TV"
                stopRequested.set(false)
                writing.set(false)
                bytesWritten = 0L
                startedAt = 0L
                outputPath = null
                lastError = null

                if (url.isNullOrBlank()) {
                    lastError = "Keine Stream-Adresse vorhanden."
                    busy.set(false)
                    stopSelfResult(startId)
                    return START_NOT_STICKY
                }

                try {
                    startForeground(NOTIFICATION_ID, buildNotification(channelName))
                } catch (_: Exception) {
                    lastError = "Der Vordergrunddienst konnte nicht gestartet werden."
                    busy.set(false)
                    stopSelfResult(startId)
                    return START_NOT_STICKY
                }

                val thread = Thread {
                    try {
                        recordStream(url, channelName)
                    } finally {
                        writing.set(false)
                        busy.set(false)
                        worker = null
                        // Stop only after the output stream has been closed.
                        // A stop command may have arrived while the worker ran.
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

    private fun recordStream(streamUrl: String, channelName: String) {
        var outputFile: File? = null
        try {
            val url = URL(streamUrl)
            require(url.protocol == "http" || url.protocol == "https") {
                "Nur HTTP(S)-Streams werden unterstützt."
            }
            require(!url.path.lowercase().endsWith(".m3u8")) {
                "HLS-Aufnahmen werden noch nicht unterstützt."
            }
            if (stopRequested.get()) return

            val http = url.openConnection() as HttpURLConnection
            connection = http
            http.connectTimeout = 15000
            http.readTimeout = 30000
            http.instanceFollowRedirects = true
            http.setRequestProperty("User-Agent", "StreamiaPlayer/1.0")
            http.connect()
            if (stopRequested.get()) return
            require(http.responseCode in 200..299) {
                "Der Stream konnte nicht geöffnet werden."
            }
            val contentType = http.contentType?.lowercase() ?: ""
            require(!contentType.contains("mpegurl") &&
                !contentType.contains("application/vnd.apple")) {
                "HLS-Playlists werden noch nicht unterstützt."
            }

            val directory = File(getExternalFilesDir(null) ?: filesDir, "recordings")
            require(directory.exists() || directory.mkdirs()) {
                "Aufnahmeordner konnte nicht erstellt werden."
            }
            val safeName = channelName
                .replace(Regex("[^A-Za-z0-9_-]"), "_")
                .take(60)
                .ifBlank { "Live_TV" }
            outputFile = File.createTempFile("${safeName}_", ".ts", directory)

            http.inputStream.use { input ->
                val header = ByteArray(188 * 3)
                var received = 0
                while (received < header.size && !stopRequested.get()) {
                    val count = input.read(header, received, header.size - received)
                    if (count < 0) break
                    if (count == 0) continue
                    received += count
                }
                if (stopRequested.get()) return
                require(received >= 188 * 2) {
                    "Zu wenige Streamdaten empfangen."
                }
                require(header[0] == 0x47.toByte() &&
                    header[188] == 0x47.toByte()) {
                    "Kein direktes MPEG-TS-Format erkannt."
                }

                outputFile.outputStream().buffered().use { output ->
                    if (stopRequested.get()) return
                    output.write(header, 0, received)
                    bytesWritten = received.toLong()
                    startedAt = SystemClock.elapsedRealtime()
                    outputPath = outputFile.absolutePath
                    writing.set(true)

                    val buffer = ByteArray(64 * 1024)
                    while (!stopRequested.get()) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count == 0) continue
                        output.write(buffer, 0, count)
                        bytesWritten += count.toLong()
                    }
                    output.flush()
                }
            }
            if (!stopRequested.get()) lastError = "Der Stream wurde beendet."
        } catch (error: Exception) {
            if (!stopRequested.get()) {
                lastError = if (error is IllegalArgumentException) {
                    error.message ?: "Streamformat nicht unterstützt."
                } else {
                    "Aufnahme durch Netzwerk- oder Speicherfehler beendet."
                }
            }
        } finally {
            writing.set(false)
            connection?.disconnect()
            connection = null
            if (bytesWritten == 0L) {
                outputFile?.delete()
                outputPath = null
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Streamia Aufnahmen", NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Status laufender Live-TV-Aufnahmen"
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(channelName: String): Notification {
        val stopIntent = Intent(this, StreamRecordingService::class.java).apply {
            action = ACTION_STOP
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, pendingFlags
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Streamia Player")
            .setContentText("Live-TV-Aufnahme: $channelName")
            .setSmallIcon(android.R.drawable.ic_media_play)
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
