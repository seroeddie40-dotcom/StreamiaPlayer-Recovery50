package com.streamia.streamia_player

import android.content.Context
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.TextureView
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import android.net.Uri
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener

/**
 * Android TV Media3 video surface embedded in a Flutter PlatformView.
 *
 * TextureView avoids SurfaceView's separate surface composition when embedded
 * in Flutter's AndroidView. Keep the public API used by TvMedia3PlatformView.
 */
class TvMedia3Playback(context: Context) : FrameLayout(context) {
    // Prefer Media3's platform hardware decoder. If a device advertises a
    // decoder that fails during initialization, try the next compatible one.
    // This is an error fallback, not a parallel decoder or software-first mode.
    private val renderersFactory = DefaultRenderersFactory(context)
        .setEnableDecoderFallback(true)
    // Bound the amount of live media queued on memory-constrained TV boxes.
    // A modest rebuffer threshold reduces repeated start/stop cycles on jittery
    // connections. These are initial values requiring real-device validation.
    private val loadControl = DefaultLoadControl.Builder()
        .setBufferDurationsMs(
            10_000, // minBufferMs
            25_000, // maxBufferMs
            1_000,  // bufferForPlaybackMs
            2_000   // bufferForPlaybackAfterRebufferMs
        )
        .build()
    private val exoPlayer = ExoPlayer.Builder(context, renderersFactory)
        .setLoadControl(loadControl)
        .build()
    // TextureView is required for composition inside Flutter's AndroidView.
    // Keep it opaque so the video layer does not request alpha blending.
    private val videoView = TextureView(context).apply { isOpaque = true }
    private var released = false
    // Suppress transient IDLE/ENDED callbacks while replacing a channel.
    private var switchingStream = false
    // Aggregate decoder health counters rather than logging every frame.
    // No stream URL, headers, credentials or channel names are logged.
    private var droppedFrames = 0L
    private var audioUnderruns = 0L
    private var lastHealthLogMs = SystemClock.elapsedRealtime()
    private val healthLogIntervalMs = 60_000L

    private fun reportHealthIfDue() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastHealthLogMs < healthLogIntervalMs) return
        if (droppedFrames > 0L || audioUnderruns > 0L) {
            Log.i("StreamiaMedia3Health", "60s decoder health: droppedFrames=$droppedFrames audioUnderruns=$audioUnderruns")
        }
        droppedFrames = 0L
        audioUnderruns = 0L
        lastHealthLogMs = now
    }

    private fun resetHealthCounters() {
        droppedFrames = 0L
        audioUnderruns = 0L
        lastHealthLogMs = SystemClock.elapsedRealtime()
    }

    var onPlaybackState: ((Int, Boolean) -> Unit)? = null
    var onPlaybackError: ((String) -> Unit)? = null

    init {
        addView(
            videoView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
        exoPlayer.setVideoTextureView(videoView)
        exoPlayer.addAnalyticsListener(object : AnalyticsListener {
            override fun onVideoDecoderInitialized(
                eventTime: AnalyticsListener.EventTime,
                decoderName: String,
                initializedTimestampMs: Long,
                initializationDurationMs: Long
            ) {
                if (!released && !switchingStream) {
                    Log.i("StreamiaMedia3Health", "Video decoder initialized: $decoderName (${initializationDurationMs}ms)")
                }
            }

            override fun onDroppedVideoFrames(
                eventTime: AnalyticsListener.EventTime,
                droppedFramesCount: Int,
                elapsedMs: Long
            ) {
                if (!released && !switchingStream) {
                    droppedFrames += droppedFramesCount.toLong()
                    reportHealthIfDue()
                }
            }

            override fun onAudioUnderrun(
                eventTime: AnalyticsListener.EventTime,
                bufferSize: Int,
                bufferSizeMs: Long,
                elapsedSinceLastFeedMs: Long
            ) {
                if (!released && !switchingStream) {
                    audioUnderruns++
                    reportHealthIfDue()
                }
            }
        })
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (!released && !switchingStream) onPlaybackState?.invoke(playbackState, exoPlayer.isPlaying)
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (!released && !switchingStream) onPlaybackState?.invoke(exoPlayer.playbackState, isPlaying)
            }

            override fun onPlayerError(error: PlaybackException) {
                // Error codes are safe to forward; exception messages may expose credentials.
                if (!released && !switchingStream) onPlaybackError?.invoke(error.errorCodeName)
            }
        })
    }

    /**
     * HLS endpoints may hide the .m3u8 extension behind a query string.
     * Only force HLS when the URL itself gives an explicit format hint;
     * otherwise let Media3 sniff progressive/TS content normally.
     * Never log or persist the URL (it can contain access credentials).
     */
    private fun mediaItemForUrl(url: String): MediaItem {
        val uri = Uri.parse(url)
        val path = uri.path.orEmpty().lowercase(java.util.Locale.ROOT)
        val explicitHlsPath = path.endsWith(".m3u8")
        val explicitHlsQuery = uri.queryParameterNames.any { name ->
            val key = name.lowercase(java.util.Locale.ROOT)
            if (key !in setOf("format", "type", "extension", "ext", "output")) {
                false
            } else {
                uri.getQueryParameters(name).any { value ->
                    value.equals("m3u8", ignoreCase = true) ||
                        value.equals("hls", ignoreCase = true)
                }
            }
        }
        val builder = MediaItem.Builder().setUri(uri)
        if (explicitHlsPath || explicitHlsQuery) {
            builder.setMimeType(MimeTypes.APPLICATION_M3U8)
        }
        return builder.build()
    }

    fun open(url: String) {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        check(!released) { "Player already released" }
        // Explicitly tear down the previous decoder/buffers before preparing
        // the next live channel. setMediaItem alone may retain resources while
        // the old source is still buffering on low-memory Android TV boxes.
        switchingStream = true
        resetHealthCounters()
        try {
            exoPlayer.playWhenReady = false
            exoPlayer.stop()
            exoPlayer.clearMediaItems()
            exoPlayer.setMediaItem(mediaItemForUrl(url))
            exoPlayer.prepare()
            exoPlayer.playWhenReady = true
        } finally {
            switchingStream = false
        }
    }

    /** Read-only state snapshot after a native open acknowledgement.
     * No new player, timer, or decoder is created.
     */
    fun playbackSnapshot(): Pair<Int, Boolean> {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        return Pair(exoPlayer.playbackState, exoPlayer.isPlaying)
    }

    fun stop() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        if (released) return
        switchingStream = true
        resetHealthCounters()
        try {
            exoPlayer.playWhenReady = false
            exoPlayer.stop()
            exoPlayer.clearMediaItems()
        } finally {
            switchingStream = false
        }
    }

    fun release() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        if (released) return
        released = true
        exoPlayer.clearVideoTextureView(videoView)
        exoPlayer.release()
        onPlaybackState = null
        onPlaybackError = null
    }
}
