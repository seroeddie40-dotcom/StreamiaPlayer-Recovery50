
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

        private val running = AtomicBoolean(false)
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
            get() = running.get()
    }

    @Volatile
    private var connection: HttpURLConnection? = null

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
        when (intent?.action) {
            ACTION_STOP -> {
                stopRequested.set(true)
                connection?.disconnect()
                if (!running.get()) stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                if (!running.compareAndSet(false, true)) {
                    return START_NOT_STICKY
                }

                val url = intent.getStringExtra(EXTRA_URL)
                val name = intent.getStringExtra(EXTRA_NAME)
                    ?: "Live_TV"

                if (url.isNullOrBlank()) {
                    lastError = "Keine Stream-Adresse vorhanden."
                    running.set(false)
                    stopSelf(startId)
                    return START_NOT_STICKY
                }

                stopRequested.set(false)
                bytesWritten = 0L
                startedAt = 0L
                lastError = null
                outputPath = null

                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(name)
                )

                Thread {
                    recordStream(url, name)
                    running.set(false)
                    stopSelf(startId)
                }.apply {
                    name = "StreamiaRecorder"
                    isDaemon = false
                    start()
                }

                return START_NOT_STICKY
            }
        }

        return START_NOT_STICKY
    }

    private fun recordStream(url: String, name: String) {
        var outputFile: File? = null

        try {
            val parsed = URL(url)

            require(
                parsed.protocol == "http" ||
                parsed.protocol == "https"
            ) {
                "Nur HTTP(S)-Streams werden unterstützt."
            }

            require(
                !parsed.path.lowercase().endsWith(".m3u8")
            ) {
                "HLS benötigt die separate Aufnahme-Engine."
            }

            val http = parsed.openConnection() as HttpURLConnection
            connection = http

            http.connectTimeout = 15000
            http.readTimeout = 30000
            http.instanceFollowRedirects = true
            http.setRequestProperty(
                "User-Agent",
                "StreamiaPlayer/1.0"
            )

            http.connect()

            require(http.responseCode in 200..299) {
                "Der Stream konnte nicht geöffnet werden."
            }

            val contentType = http.contentType
                ?.lowercase()
                ?: ""

            require(
                !contentType.contains("mpegurl") &&
                !contentType.contains("application/vnd.apple")
            ) {
                "HLS-Playlists werden noch nicht unterstützt."
            }

            val directory = File(
                getExternalFilesDir(null) ?: filesDir,
                "recordings"
            )

            require(
                directory.exists() || directory.mkdirs()
            ) {
                "Aufnahmeordner konnte nicht erstellt werden."
            }

            val safeName = name
                .replace(
                    Regex("[^A-Za-z0-9_-]"),
                    "_"
                )
                .take(60)
                .ifBlank { "Live_TV" }

            outputFile = File(
                directory,
                "${safeName}_${System.currentTimeMillis()}.ts"
            )

            http.inputStream.use { input ->
                val firstBytes = ByteArray(188 * 3)
                var received = 0

                while (
                    received < firstBytes.size &&
                    !stopRequested.get()
                ) {
                    val count = input.read(
                        firstBytes,
                        received,
                        firstBytes.size - received
                    )

                    if (count < 0) break
                    received += count
                }

                require(received >= 188 * 2) {
                    "Zu wenige Streamdaten empfangen."
                }

                val isTransportStream =
                    firstBytes[0] == 0x47.toByte() &&
                    firstBytes[188] == 0x47.toByte()

                require(isTransportStream) {
                    "Kein direktes MPEG-TS-Format erkannt."
                }

                outputFile.outputStream().buffered().use { output ->
                    output.write(firstBytes, 0, received)
                    bytesWritten += received
                    startedAt = SystemClock.elapsedRealtime()
                    outputPath = outputFile.absolutePath

                    val buffer = ByteArray(64 * 1024)

                    while (!stopRequested.get()) {
                        val count = input.read(buffer)

                        if (count < 0) break
                        if (count == 0) continue

                        output.write(buffer, 0, count)
                        bytesWritten += count
                    }

                    output.flush()
                }
            }

            if (!stopRequested.get()) {
                lastError = "Der Stream wurde beendet."
            }

        } catch (error: Exception) {
            if (!stopRequested.get()) {
                lastError = when (error) {
                    is IllegalArgumentException ->
                        error.message ?: "Streamformat nicht unterstützt."
                    else -> "Aufnahme durch Netzwerk- oder Speicherfehler beendet."
                }
            }
        } finally {
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
                CHANNEL_ID,
                "Streamia Aufnahmen",
                NotificationManager.IMPORTANCE_LOW
            )

            channel.description =
                "Status laufender Live-TV-Aufnahmen"

            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(name: String): Notification {
        val stopIntent = Intent(
            this,
            StreamRecordingService::class.java
        ).apply {
            action = ACTION_STOP
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= 23)
                PendingIntent.FLAG_IMMUTABLE
            else 0

        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            flags
        )

        val builder = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        ) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Streamia Player")
            .setContentText("Aufnahme wird vorbereitet: $name")
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
        super.onDestroy()
    }
}
