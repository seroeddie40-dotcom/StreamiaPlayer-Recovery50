package com.streamia.streamia_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.SurfaceView
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

/**
 * Isolated Android-TV Media3 playback surface.
 * Not yet wired to Flutter: integration must also implement lifecycle,
 * channel switching and event forwarding before this is used in production.
 */
class TvMedia3Playback(context: Context) : FrameLayout(context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val exoPlayer = ExoPlayer.Builder(context).build()
    private val playerView = PlayerView(context).apply {
        useController = false
        player = exoPlayer
    }

    var onPlaybackState: ((Int, Boolean) -> Unit)? = null
    var onPlaybackError: ((String) -> Unit)? = null

    init {
        addView(playerView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                onPlaybackState?.invoke(playbackState, exoPlayer.isPlaying)
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                onPlaybackState?.invoke(exoPlayer.playbackState, isPlaying)
            }
            override fun onPlayerError(error: PlaybackException) {
                // Never forward stream URLs or exception messages: Xtream URLs may contain credentials.
                onPlaybackError?.invoke(error.errorCodeName)
            }
        })
    }

    fun open(url: String) {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        exoPlayer.setMediaItem(MediaItem.fromUri(url))
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    fun stop() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
    }

    fun release() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        playerView.player = null
        exoPlayer.release()
        onPlaybackState = null
        onPlaybackError = null
        mainHandler.removeCallbacksAndMessages(null)
    }
}
