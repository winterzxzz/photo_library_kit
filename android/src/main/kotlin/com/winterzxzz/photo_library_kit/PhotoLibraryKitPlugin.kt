package com.winterzxzz.photo_library_kit

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicInteger

/** Entry point. Queries and thumbnails run on dedicated pools; replies return on the main thread. */
class PhotoLibraryKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var context: Context
  private lateinit var queries: MediaQueries
  private lateinit var thumbnails: ThumbnailLoader
  private lateinit var writer: MediaWriter
  private lateinit var permissions: PermissionManager
  private lateinit var observer: ChangeObserver

  private val main = Handler(Looper.getMainLooper())
  private var activityBinding: ActivityPluginBinding? = null
  private val activity: Activity? get() = activityBinding?.activity

  /** Metadata queries: few threads, they are I/O bound on the same database. */
  private val queryPool: ExecutorService = Executors.newFixedThreadPool(2, named("query"))

  /** Thumbnail decoding is CPU bound. */
  private val thumbPool: ExecutorService = Executors.newFixedThreadPool(
    Runtime.getRuntime().availableProcessors().coerceIn(2, 4),
    named("thumb"),
  )

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    queries = MediaQueries(context.contentResolver)
    thumbnails = ThumbnailLoader(context.contentResolver, queries)
    writer = MediaWriter(context, queries)
    permissions = PermissionManager(context)
    observer = ChangeObserver(context.contentResolver, queries.filesUri)
    channel = MethodChannel(binding.binaryMessenger, "photo_library_kit")
    channel.setMethodCallHandler(this)
    events = EventChannel(binding.binaryMessenger, "photo_library_kit/changes")
    events.setStreamHandler(observer)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    events.setStreamHandler(null)
    observer.onCancel(null)
    queryPool.shutdownNow()
    thumbPool.shutdownNow()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPermissionState" -> result.success(permissions.state(wanted(call)))
      "requestPermission" -> permissions.request(activity, wanted(call)) { main.post { result.success(it) } }
      "presentLimitedPicker" -> permissions.request(activity, wanted(call)) { main.post { result.success(null) } }
      "openSettings" -> result.success(openSettings())
      "getAlbums" -> query(result) {
        queries.albums(MediaFilter.from(call.argument("filter")), call.argument<Boolean>("includeEmpty") == true)
      }
      "getAssetCount" -> query(result) {
        queries.count(call.argument<String>("album")!!, MediaFilter.from(call.argument("filter")))
      }
      "getAssets" -> query(result) {
        queries.assets(
          call.argument<String>("album")!!,
          MediaFilter.from(call.argument("filter")),
          call.argument<Int>("start")!!,
          call.argument<Int>("end")!!,
        )
      }
      "getAsset" -> query(result) { queries.asset(call.argument<String>("id")!!) }
      "getThumbnail" -> thumbnail(call, result)
      "cancelThumbnail" -> {
        thumbnails.cancel(call.argument<Int>("rid")!!)
        result.success(null)
      }
      // Android has no app-level thumbnail cache to warm; the system one is shared.
      "startCaching", "stopCaching" -> result.success(null)
      "getFilePath" -> query(result) { writer.filePath(call.argument<String>("id")!!) }
      "saveImage" -> query(result) {
        writer.saveImage(call.argument<ByteArray>("bytes")!!, call.argument<String>("filename")!!)
          ?.let(queries::asset)
      }
      "saveVideo" -> query(result) {
        writer.saveVideo(call.argument<String>("path")!!, call.argument<String>("filename"))
          ?.let(queries::asset)
      }
      "deleteAssets" -> delete(call.argument<List<String>>("ids")!!, result)
      "clearFileCache" -> query(result) { writer.clearCache() }
      else -> result.notImplemented()
    }
  }

  private fun wanted(call: MethodCall) = permissions.permissionsFor(
    images = call.argument<Boolean>("images") ?: true,
    videos = call.argument<Boolean>("videos") ?: true,
  )

  private fun thumbnail(call: MethodCall, result: Result) {
    val rid = call.argument<Int>("rid")!!
    val req = ThumbnailRequest(
      id = call.argument<String>("id")!!.toLongOrNull() ?: return result.success(null),
      isVideo = call.argument<Int>("type") == 1,
      width = call.argument<Int>("w")!!,
      height = call.argument<Int>("h")!!,
      quality = call.argument<Int>("q") ?: 85,
      png = call.argument<Int>("fmt") == 1,
      cover = call.argument<Int>("fit") != 1,
    )
    val signal = thumbnails.register(rid)
    thumbPool.execute {
      try {
        val bytes = thumbnails.load(req, signal)
        main.post { result.success(bytes) }
      } catch (e: Throwable) {
        main.post { result.error("io_error", e.message, null) }
      } finally {
        thumbnails.finish(rid)
      }
    }
  }

  private fun delete(ids: List<String>, result: Result) {
    try {
      writer.delete(activity, ids) { deleted -> main.post { result.success(deleted) } }
    } catch (e: IllegalStateException) {
      result.error("no_activity", "Deleting requires a foreground activity", null)
    } catch (e: Exception) {
      result.error("io_error", e.message, null)
    }
  }

  private fun openSettings(): Boolean = try {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    (activity ?: context).startActivity(intent)
    true
  } catch (_: Exception) {
    false
  }

  private fun <T> query(result: Result, block: () -> T) {
    queryPool.execute {
      try {
        val value = block()
        main.post { result.success(if (value is Unit) null else value) }
      } catch (e: SecurityException) {
        main.post { result.error("permission_denied", e.message, null) }
      } catch (e: Throwable) {
        main.post { result.error("io_error", e.message, null) }
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addRequestPermissionsResultListener(permissions)
    binding.addActivityResultListener(writer)
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(permissions)
    activityBinding?.removeActivityResultListener(writer)
    activityBinding = null
  }

  private companion object {
    fun named(prefix: String): ThreadFactory {
      val n = AtomicInteger()
      return ThreadFactory { r ->
        Thread(r, "photo_library_kit-$prefix-${n.incrementAndGet()}").apply {
          isDaemon = true
          priority = Thread.NORM_PRIORITY - 1
        }
      }
    }
  }
}
