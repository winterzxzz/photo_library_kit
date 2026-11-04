package com.winterzxzz.photo_library_kit

import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileInputStream
import java.io.InputStream

/** Saving, deleting and exporting files. Blocking calls run off the main thread. */
internal class MediaWriter(
  private val context: Context,
  private val queries: MediaQueries,
) : PluginRegistry.ActivityResultListener {

  private val resolver: ContentResolver = context.contentResolver
  private var pendingDelete: Pair<List<String>, (List<String>) -> Unit>? = null

  val cacheDir: File get() = File(context.cacheDir, "photo_library_kit")

  fun saveImage(bytes: ByteArray, filename: String): String? =
    insert(bytes.inputStream(), filename, isVideo = false)

  fun saveVideo(path: String, filename: String?): String? =
    FileInputStream(path).use { insert(it, filename ?: File(path).name, isVideo = true) }

  private fun insert(input: InputStream, filename: String, isVideo: Boolean): String? {
    val mime = MimeTypeMap.getSingleton()
      .getMimeTypeFromExtension(filename.substringAfterLast('.', "").lowercase())
      ?: if (isVideo) "video/mp4" else "image/jpeg"
    val collection = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
    else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    val dirName = if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
    val values = ContentValues().apply {
      put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
      put(MediaStore.MediaColumns.MIME_TYPE, mime)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      values.put(MediaStore.MediaColumns.RELATIVE_PATH, dirName)
      values.put(MediaStore.MediaColumns.IS_PENDING, 1)
      val uri = resolver.insert(collection, values) ?: return null
      try {
        resolver.openOutputStream(uri)?.use { input.copyTo(it) } ?: error("Cannot open $uri")
        resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
      } catch (e: Exception) {
        resolver.delete(uri, null, null)
        throw e
      }
      return ContentUris.parseId(uri).toString()
    }
    @Suppress("DEPRECATION")
    val dir = Environment.getExternalStoragePublicDirectory(dirName).apply { mkdirs() }
    val file = uniqueFile(dir, filename)
    file.outputStream().use { input.copyTo(it) }
    @Suppress("DEPRECATION")
    values.put(MediaStore.MediaColumns.DATA, file.absolutePath)
    val uri = resolver.insert(collection, values) ?: return null
    return ContentUris.parseId(uri).toString()
  }

  private fun uniqueFile(dir: File, name: String): File {
    var file = File(dir, name)
    var i = 1
    val base = name.substringBeforeLast('.')
    val ext = name.substringAfterLast('.', "")
    while (file.exists()) {
      file = File(dir, if (ext.isEmpty()) "$base ($i)" else "$base ($i).$ext")
      i++
    }
    return file
  }

  /** Deletes with the system confirmation dialog on Android 11+. */
  fun delete(activity: Activity?, ids: List<String>, done: (List<String>) -> Unit) {
    val uris = ids.mapNotNull { id ->
      val numeric = id.toLongOrNull() ?: return@mapNotNull null
      ContentUris.withAppendedId(queries.filesUri, numeric)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      if (activity == null) throw IllegalStateException("no_activity")
      if (pendingDelete != null) throw IllegalStateException("busy")
      val request = MediaStore.createDeleteRequest(resolver, uris)
      pendingDelete = ids to done
      activity.startIntentSenderForResult(request.intentSender, DELETE_REQUEST, null, 0, 0, 0)
      return
    }
    val deleted = ArrayList<String>()
    uris.forEachIndexed { i, uri ->
      try {
        if (resolver.delete(uri, null, null) > 0) deleted += ids[i]
      } catch (_: SecurityException) {
        // Android 10 requires per-item consent for media owned by other apps.
      }
    }
    done(deleted)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != DELETE_REQUEST) return false
    val (ids, done) = pendingDelete ?: return true
    pendingDelete = null
    done(if (resultCode == Activity.RESULT_OK) ids else emptyList())
    return true
  }

  /** A readable path: the MediaStore file itself, or a cached copy as a fallback. */
  fun filePath(id: String): String? {
    queries.dataPath(id)?.let { path ->
      val f = File(path)
      if (f.canRead()) return path
    }
    val numeric = id.toLongOrNull() ?: return null
    val uri: Uri = ContentUris.withAppendedId(queries.filesUri, numeric)
    val (mime, modified) = queries.mimeAndModified(id) ?: return null
    val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
    // Keyed by modification time so edits never return a stale copy.
    val out = File(cacheDir.apply { mkdirs() }, "${id}_$modified.$ext")
    if (out.exists()) return out.absolutePath
    // Unique temp + rename: a failed or concurrent copy never publishes a
    // partial file.
    val tmp = File.createTempFile("$id-", ".part", cacheDir)
    try {
      resolver.openInputStream(uri)?.use { input -> tmp.outputStream().use { input.copyTo(it) } }
        ?: return null
      if (!tmp.renameTo(out) && !out.exists()) return null
    } finally {
      tmp.delete()
    }
    return out.absolutePath
  }

  fun clearCache() {
    cacheDir.deleteRecursively()
  }

  companion object {
    private const val DELETE_REQUEST = 0x5049
  }
}
