package com.streamia.streamia_player

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
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

    // Flutter's PlatformView.dispose() is not guaranteed to run when Android Home
    // sends the hosting Activity into the background. Stop native playback there.
    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityPaused(activity: Activity) {
            if (activity === hostActivity && !disposed) playback.stop()
        }
        override fun onActivityStopped(activity: Activity) {
            if (activity === hostActivity && !disposed) playback.stop()
        }
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityResumed(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) {
            if (activity === hostActivity && !disposed) dispose()
        }
    }

    init {
        application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
        channel.setMethodCallHandler(this)
        playback.onPlaybackState = { state, playing ->
            if (!disposed) {
                channel.invokeMethod("state", mapOf("state" to state, "playing" to playing))
            }
        }
        playback.onPlaybackError = { code ->
            if (!disposed) channel.invokeMethod("error", mapOf("code" to code))
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
                if (url.isNullOrBlank() ||
                    !(url.startsWith("http://", true) || url.startsWith("https://", true))) {
                    result.error("INVALID_URL", "Expected an HTTP(S) stream URL", null)
                    return
                }
                if (hostActivity != null && !hostActivityHasFocus()) {
                    result.error("APP_BACKGROUND", "Cannot start TV playback while app is paused", null)
                    return
                }
                try {
                    playback.open(url)
                    result.success(null)
                } catch (_: Exception) {
                    result.error("OPEN_FAILED", "Native player could not open stream", null)
                }
            }
            "stop" -> {
                playback.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Window focus is not a reliable indication of lifecycle (dialogs may take
    // focus), so only check whether the Activity is finishing/destroyed here.
    private fun hostActivityHasFocus(): Boolean =
        hostActivity?.let { !it.isFinishing && !it.isDestroyed } ?: true

    override fun dispose() {
        if (disposed) return
        disposed = true
        application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        channel.setMethodCallHandler(null)
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
