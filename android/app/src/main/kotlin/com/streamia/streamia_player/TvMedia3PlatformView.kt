package com.streamia.streamia_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

/**
 * Android TV Media3 PlatformView bridge.
 * Register this factory with FlutterEngine.platformViewsController.registry
 * before creating an AndroidView of viewType [VIEW_TYPE].
 */
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

    private val mainHandler = Handler(Looper.getMainLooper())
    private val playback = TvMedia3Playback(context)
    private val channel = MethodChannel(messenger, "com.streamia/tv_media3_view/$viewId")
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
        playback.onPlaybackState = { state, playing ->
            if (!disposed) {
                channel.invokeMethod(
                    "state",
                    mapOf("state" to state, "playing" to playing)
                )
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

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        playback.release()
        mainHandler.removeCallbacksAndMessages(null)
    }
}
