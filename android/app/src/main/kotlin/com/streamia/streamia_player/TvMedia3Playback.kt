package com.streamia.streamia_player

import android.content.Context
import android.os.Looper
import android.view.TextureView
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/**
 * Android TV Media3 video surface embedded in a Flutter PlatformView.
 *
 * TextureView avoids SurfaceView's separate surface composition when embedded
 * in Flutter's AndroidView. Keep the public API used by TvMedia3PlatformView.
 */
class TvMedia3Playback(context: Context) : FrameLayout(context) {
    private val exoPlayer = ExoPlayer.Builder(context).build()
    private val videoView = TextureView(context)
    private var released = false

    var onPlaybackState: ((Int, Boolean) -> Unit)? = null
    var onPlaybackError: ((String) -> Unit)? = null

    init {
        addView(
            videoView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
        exoPlayer.setVideoTextureView(videoView)
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (!released) onPlaybackState?.invoke(playbackState, exoPlayer.isPlaying)
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (!released) onPlaybackState?.invoke(exoPlayer.playbackState, isPlaying)
            }

            override fun onPlayerError(error: PlaybackException) {
                // Error codes are safe to forward; exception messages may expose credentials.
                if (!released) onPlaybackError?.invoke(error.errorCodeName)
            }
        })
    }

    fun open(url: String) {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        check(!released) { "Player already released" }
        exoPlayer.setMediaItem(MediaItem.fromUri(url))
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    fun stop() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Must run on main thread" }
        if (released) return
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
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
