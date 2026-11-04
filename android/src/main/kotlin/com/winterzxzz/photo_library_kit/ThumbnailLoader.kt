package com.winterzxzz.photo_library_kit

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.os.Build
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.provider.MediaStore
import android.util.Size
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal class ThumbnailRequest(
  val id: Long,
  val isVideo: Boolean,
  val width: Int,
  val height: Int,
  val quality: Int,
  val png: Boolean,
  val cover: Boolean,
)

/**
 * Produces encoded thumbnails at exactly the requested size.
 *
 * Small requests use the system thumbnail cache (`loadThumbnail`, API 29+),
 * which is already scaled and rotated. Larger previews decode the original
 * with subsampling so memory stays proportional to the output size.
 */
internal class ThumbnailLoader(
  private val resolver: ContentResolver,
  private val queries: MediaQueries,
) {
  private val signals = ConcurrentHashMap<Int, CancellationSignal>()

  /** Registers a request before it is queued so it can be cancelled early. */
  fun register(requestId: Int): CancellationSignal =
    CancellationSignal().also { signals[requestId] = it }

  fun cancel(requestId: Int) {
    signals.remove(requestId)?.cancel()
  }

  fun finish(requestId: Int) {
    signals.remove(requestId)
  }

  /** Returns `null` when the asset is missing or the request was cancelled. */
  fun load(req: ThumbnailRequest, signal: CancellationSignal): ByteArray? {
    if (signal.isCanceled) return null
    val decoded = try {
      decode(req, signal)
    } catch (_: OperationCanceledException) {
      return null
    } catch (_: java.io.FileNotFoundException) {
      return null
    } ?: return null
    if (signal.isCanceled) {
      decoded.recycle()
      return null
    }
    val fitted = fit(decoded, req)
    return try {
      ByteArrayOutputStream(fitted.byteCount / 8).use { out ->
        fitted.compress(
          if (req.png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG,
          req.quality,
          out,
        )
        out.toByteArray()
      }
    } finally {
      fitted.recycle()
    }
  }

  private fun decode(req: ThumbnailRequest, signal: CancellationSignal): Bitmap? {
    val uri = MediaQueries.contentUri(req.id, req.isVideo)
    val longest = max(req.width, req.height)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && longest <= SYSTEM_THUMB_MAX) {
      return resolver.loadThumbnail(uri, Size(req.width, req.height), signal)
    }
    if (req.isVideo) {
      // The system video thumbnail is small; previews need a real frame.
      return videoFrame(uri, req) ?: legacyVideoFrame(req)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      val source = ImageDecoder.createSource(resolver, uri)
      return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        decoder.setTargetSampleSize(sampleSize(info.size.width, info.size.height, req))
      }
    }
    return legacyImage(req)
  }

  private fun videoFrame(uri: android.net.Uri, req: ThumbnailRequest): Bitmap? {
    val retriever = MediaMetadataRetriever()
    return try {
      resolver.openFileDescriptor(uri, "r")?.use { fd ->
        retriever.setDataSource(fd.fileDescriptor)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
          val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
          val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
          val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
          val (vw, vh) = if (rotation == 90 || rotation == 270) h to w else w to h
          if (vw > 0 && vh > 0) {
            // Scale to cover (or fit) the request without upscaling.
            val scale = min(1f, if (req.cover) max(req.width / vw.toFloat(), req.height / vh.toFloat())
            else min(req.width / vw.toFloat(), req.height / vh.toFloat()))
            return@use retriever.getScaledFrameAtTime(
              0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
              (vw * scale).roundToInt().coerceAtLeast(1), (vh * scale).roundToInt().coerceAtLeast(1),
            )
          }
        }
        retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
      }
    } catch (_: RuntimeException) {
      null
    } finally {
      retriever.release()
    }
  }

  @Suppress("DEPRECATION")
  private fun legacyVideoFrame(req: ThumbnailRequest): Bitmap? {
    val path = queries.dataPath(req.id.toString()) ?: return null
    val kind = if (max(req.width, req.height) <= 96) MediaStore.Images.Thumbnails.MICRO_KIND
    else MediaStore.Images.Thumbnails.MINI_KIND
    ThumbnailUtils.createVideoThumbnail(path, kind)?.let { return it }
    val retriever = MediaMetadataRetriever()
    return try {
      retriever.setDataSource(path)
      retriever.frameAtTime
    } catch (_: RuntimeException) {
      null
    } finally {
      retriever.release()
    }
  }

  private fun legacyImage(req: ThumbnailRequest): Bitmap? {
    val path = queries.dataPath(req.id.toString()) ?: return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0) return null
    val opts = BitmapFactory.Options().apply {
      inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, req)
    }
    val bitmap = BitmapFactory.decodeFile(path, opts) ?: return null
    val orientation = queries.asset(req.id.toString())?.get("ori") as? Int ?: 0
    if (orientation == 0) return bitmap
    val rotated = Bitmap.createBitmap(
      bitmap, 0, 0, bitmap.width, bitmap.height,
      Matrix().apply { postRotate(orientation.toFloat()) }, true,
    )
    if (rotated !== bitmap) bitmap.recycle()
    return rotated
  }

  /** Largest power of two that keeps the decoded image at least the target size. */
  private fun sampleSize(srcW: Int, srcH: Int, req: ThumbnailRequest): Int {
    val ratio = if (req.cover) min(srcW / req.width.toFloat(), srcH / req.height.toFloat())
    else max(srcW / req.width.toFloat(), srcH / req.height.toFloat())
    var sample = 1
    while (sample * 2 <= ratio) sample *= 2
    return sample
  }

  /** Scales (never up) and center-crops for cover, or scales to fit for contain. */
  private fun fit(src: Bitmap, req: ThumbnailRequest): Bitmap {
    val sw = src.width.toFloat()
    val sh = src.height.toFloat()
    return if (req.cover) {
      val scale = min(1f, max(req.width / sw, req.height / sh))
      val cropW = min(sw, req.width / scale)
      val cropH = min(sh, req.height / scale)
      val outW = (cropW * scale).roundToInt().coerceAtLeast(1)
      val outH = (cropH * scale).roundToInt().coerceAtLeast(1)
      if (outW == src.width && outH == src.height) return src
      val x = ((sw - cropW) / 2).toInt()
      val y = ((sh - cropH) / 2).toInt()
      val w = cropW.roundToInt().coerceIn(1, src.width - x)
      val h = cropH.roundToInt().coerceIn(1, src.height - y)
      val matrix = Matrix().apply { setScale(scale, scale) }
      val out = Bitmap.createBitmap(src, x, y, w, h, matrix, true)
      if (out !== src) src.recycle()
      out
    } else {
      val scale = min(1f, min(req.width / sw, req.height / sh))
      if (scale >= 1f) return src
      val out = Bitmap.createScaledBitmap(
        src, (sw * scale).roundToInt().coerceAtLeast(1), (sh * scale).roundToInt().coerceAtLeast(1), true,
      )
      if (out !== src) src.recycle()
      out
    }
  }

  companion object {
    /** Above this the system thumbnail cache is too small and looks blurry. */
    const val SYSTEM_THUMB_MAX = 512
  }
}
