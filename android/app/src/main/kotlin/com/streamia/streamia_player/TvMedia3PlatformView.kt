package com.streamia.streamia_player

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.net.Uri
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Native Media3 view factory for Android TV live playback. */
class TvMedia3PlatformViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    companion object {
        const val VIEW_TYPE = "com.streamia/tv_media3_view"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        TvMedia3PlatformView(context, messenger, viewId)
}

private class TvMedia3PlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int
) : PlatformView, MethodChannel.MethodCallHandler {

    private val playback = TvMedia3Playback(context)
    private val channel = MethodChannel(messenger, "com.streamia/tv_media3_view/$viewId")
    private val hostActivity: Activity? = findActivity(context)
    private val application = context.applicationContext as Application
    private var disposed = false
    // Reject queued Flutter opens after Android has paused the hosting Activity.
    private var hostPaused = false
    // Identifies the current stream across queued platform-channel messages.
    private var streamGeneration = 0L

    // Media3 decoders are scarce on Android TV. The catalogue preview and the
    // fullscreen player must never retain two active video decoders. Platform
    // views can coexist briefly during Flutter route transitions.
    private companion object {
        var activeOwner: TvMedia3PlatformView? = null
    }

    private fun relinquishDecoder() {
        streamGeneration++
        playback.stop()
        if (activeOwner === this) activeOwner = null
    }

    // Flutter's PlatformView.dispose() is not guaranteed to run when Android Home
    // sends the hosting Activity into the background. Stop native playback there.
    // Android normally calls onPause followed by onStop. Invalidate the
    // generation and stop the decoder only once per background transition.
    private fun suspendPlaybackForBackground() {
        if (disposed || hostPaused) return
        hostPaused = true
        relinquishDecoder()
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityPaused(activity: Activity) {
            if (activity === hostActivity) suspendPlaybackForBackground()
        }
        override fun onActivityStopped(activity: Activity) {
            if (activity === hostActivity) suspendPlaybackForBackground()
        }
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityResumed(activity: Activity) {
            if (activity === hostActivity && !disposed) hostPaused = false
        }
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) {
            if (activity === hostActivity && !disposed) dispose()
        }
    }

    init {
        application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
        channel.setMethodCallHandler(this)
        playback.onPlaybackState = { state, playing ->
            if (!disposed && !hostPaused && activeOwner === this) {
                channel.invokeMethod("state", mapOf("state" to state, "playing" to playing, "generation" to streamGeneration))
            }
        }
        playback.onPlaybackError = { code ->
            if (!disposed && !hostPaused && activeOwner === this) channel.invokeMethod("error", mapOf("code" to code, "generation" to streamGeneration))
        }
    }

    override fun getView(): View = playback

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("DISPOSED", "Player already released", null)
            return
        }
        when (call.method) {
            "open" -> {
                val url = call.argument<String>("url")
                // Validate the URI structurally, not just by its prefix.
                // A malformed replacement must not leave this view's previous
                // stream running in the background. Never log credential URLs.
                val parsed = try { if (url.isNullOrBlank()) null else Uri.parse(url) }
                    catch (_: Exception) { null }
                val validUrl = parsed != null &&
                    (parsed.scheme.equals("http", true) || parsed.scheme.equals("https", true)) &&
                    !parsed.host.isNullOrBlank()
                if (!validUrl) {
                    if (activeOwner === this) relinquishDecoder()
                    result.error("INVALID_URL", "Expected an HTTP(S) stream URL with a host", null)
                    return
                }
                if (hostPaused || (hostActivity != null && !hostActivityIsAlive())) {
                    result.error("APP_BACKGROUND", "Cannot start TV playback while app is paused", null)
                    return
                }
                try {
                    // Stop the previous view synchronously on the Android main
                    // thread before opening this view's stream. This also
                    // protects against delayed PlatformView disposal.
                    if (activeOwner !== this) activeOwner?.relinquishDecoder()
                    activeOwner = this
                    streamGeneration++
                    playback.open(url)
                    result.success(streamGeneration)
                } catch (_: Exception) {
                    relinquishDecoder()
                    result.error("OPEN_FAILED", "Native player could not open stream", null)
                }
            }
            "snapshot" -> {
                // A previous PlatformView can remain mounted briefly after a
                // fullscreen handoff. Never report its stopped state as the
                // current stream's state, even when Flutter still has its
                // earlier generation acknowledgement.
                if (hostPaused || activeOwner !== this) {
                    result.error("STALE_OWNER", "TV playback ownership changed", null)
                    return
                }
                // Flutter may miss synchronous state changes during open().
                // A generation-tagged snapshot reconciles the first state.
                val (state, playing) = playback.playbackSnapshot()
                result.success(mapOf(
                    "state" to state,
                    "playing" to playing,
                    "generation" to streamGeneration
                ))
            }
            "stop" -> {
                relinquishDecoder()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Window focus is not a reliable indication of lifecycle (dialogs may take
    // focus), so only check whether the Activity is finishing/destroyed here.
    private fun hostActivityIsAlive(): Boolean =
        hostActivity?.let { !it.isFinishing && !it.isDestroyed } ?: true

    override fun dispose() {
        if (disposed) return
        disposed = true
        application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        channel.setMethodCallHandler(null)
        if (activeOwner === this) activeOwner = null
        playback.release()
    }

    private fun findActivity(context: Context): Activity? {
        var current: Context = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            val base = current.baseContext
            if (base === current) break
            current = base
        }
        return null
    }
}
