package com.winterzxzz.photo_library_kit

import android.content.ContentResolver
import android.content.ContentUris
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore

/** Read-only MediaStore queries. All methods block; call them off the main thread. */
internal class MediaQueries(private val resolver: ContentResolver) {

  val filesUri: Uri = MediaStore.Files.getContentUri("external")

  private val assetProjection: Array<String> = buildList {
    add(MediaStore.MediaColumns._ID)
    add(MediaStore.Files.FileColumns.MEDIA_TYPE)
    add(MediaStore.MediaColumns.MIME_TYPE)
    add(MediaStore.MediaColumns.WIDTH)
    add(MediaStore.MediaColumns.HEIGHT)
    add(MediaFilter.COL_DURATION)
    add(MediaStore.MediaColumns.DATE_ADDED)
    add(MediaStore.MediaColumns.DATE_MODIFIED)
    add(MediaFilter.COL_DATE_TAKEN)
    add(MediaFilter.COL_ORIENTATION)
    add(MediaStore.MediaColumns.DISPLAY_NAME)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) add(MediaStore.MediaColumns.IS_FAVORITE)
  }.toTypedArray()

  fun albums(filter: MediaFilter, includeEmpty: Boolean): List<Map<String, Any?>> {
    val (selection, args) = filter.selection(null)
    val counts = LinkedHashMap<String, IntArray>()
    val names = HashMap<String, String>()
    val covers = HashMap<String, String>()
    var total = 0
    var allCover: String? = null
    // One pass over three narrow columns. Rows arrive newest first, so the first
    // row seen for a bucket is its cover.
    query(
      arrayOf(MediaStore.MediaColumns._ID, MediaFilter.COL_BUCKET_ID, MediaFilter.COL_BUCKET_NAME),
      selection, args, filter.orderBy, null, null,
    )?.use { c ->
      val idCol = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
      val bucketCol = c.getColumnIndexOrThrow(MediaFilter.COL_BUCKET_ID)
      val nameCol = c.getColumnIndexOrThrow(MediaFilter.COL_BUCKET_NAME)
      while (c.moveToNext()) {
        val id = c.getLong(idCol).toString()
        total++
        if (allCover == null) allCover = id
        val bucket = c.getString(bucketCol) ?: continue
        val slot = counts.getOrPut(bucket) {
          names[bucket] = c.getString(nameCol) ?: ""
          covers[bucket] = id
          IntArray(1)
        }
        slot[0]++
      }
    }
    val result = ArrayList<Map<String, Any?>>(counts.size + 1)
    if (total > 0 || includeEmpty) {
      result += mapOf("id" to ALL_ID, "name" to "Recent", "count" to total, "kind" to 0, "cover" to allCover)
    }
    counts.entries
      .sortedByDescending { it.value[0] }
      .forEach { (bucket, count) ->
        result += mapOf(
          "id" to bucket,
          "name" to names[bucket],
          "count" to count[0],
          "kind" to 2,
          "cover" to covers[bucket],
        )
      }
    return result
  }

  fun count(albumId: String, filter: MediaFilter): Int {
    val (selection, args) = filter.selection(bucketOf(albumId))
    return query(arrayOf(MediaStore.MediaColumns._ID), selection, args, null, null, null)
      ?.use { it.count } ?: 0
  }

  fun assets(albumId: String, filter: MediaFilter, start: Int, end: Int): List<Map<String, Any?>> {
    val (selection, args) = filter.selection(bucketOf(albumId))
    val limit = end - start
    if (limit <= 0) return emptyList()
    return query(assetProjection, selection, args, filter.orderBy, limit, start)?.use { c ->
      val reader = RowReader(c)
      val out = ArrayList<Map<String, Any?>>(limit)
      while (c.moveToNext()) out += reader.read()
      out
    } ?: emptyList()
  }

  fun asset(id: String): Map<String, Any?>? {
    val numeric = id.toLongOrNull() ?: return null
    return query(
      assetProjection, "${MediaStore.MediaColumns._ID} = ?", arrayOf(numeric.toString()),
      null, null, null,
    )?.use { c -> if (c.moveToFirst()) RowReader(c).read() else null }
  }

  /** Path of the file on disk (readable with media permission on all API levels). */
  fun dataPath(id: String): String? = query(
    arrayOf(MediaStore.MediaColumns.DATA), "${MediaStore.MediaColumns._ID} = ?", arrayOf(id),
    null, null, null,
  )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }

  /** MIME type and modification time (seconds) used to key cached copies. */
  fun mimeAndModified(id: String): Pair<String?, Long>? = query(
    arrayOf(MediaStore.MediaColumns.MIME_TYPE, MediaStore.MediaColumns.DATE_MODIFIED),
    "${MediaStore.MediaColumns._ID} = ?", arrayOf(id), null, null, null,
  )?.use { c -> if (c.moveToFirst()) c.getString(0) to c.getLong(1) else null }

  private fun bucketOf(albumId: String): String? = if (albumId == ALL_ID) null else albumId

  private fun query(
    projection: Array<String>,
    selection: String,
    args: Array<String>,
    orderBy: String?,
    limit: Int?,
    offset: Int?,
  ): Cursor? {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      val bundle = Bundle().apply {
        putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
        putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
        if (orderBy != null) putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, orderBy)
        if (limit != null) putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
        if (offset != null) putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
      }
      return resolver.query(filesUri, projection, bundle, null)
    }
    var sort = orderBy
    if (limit != null) sort = "${orderBy ?: "${MediaStore.MediaColumns._ID} DESC"} LIMIT $limit OFFSET ${offset ?: 0}"
    return resolver.query(filesUri, projection, selection, args, sort)
  }

  /** Resolves column indexes once per cursor instead of once per row. */
  private class RowReader(private val c: Cursor) {
    private val id = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
    private val type = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
    private val mime = c.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
    private val width = c.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH)
    private val height = c.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT)
    private val duration = c.getColumnIndexOrThrow(MediaFilter.COL_DURATION)
    private val added = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
    private val modified = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
    private val taken = c.getColumnIndexOrThrow(MediaFilter.COL_DATE_TAKEN)
    private val orientation = c.getColumnIndexOrThrow(MediaFilter.COL_ORIENTATION)
    private val name = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
    private val favorite =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) c.getColumnIndex(MediaStore.MediaColumns.IS_FAVORITE) else -1

    fun read(): Map<String, Any?> {
      val isVideo = c.getInt(type) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
      val ori = if (c.isNull(orientation)) 0 else c.getInt(orientation)
      var w = c.getInt(width)
      var h = c.getInt(height)
      // Both images and videos (API 30+ fills orientation for videos) store
      // raw dimensions; report them as displayed.
      if (ori == 90 || ori == 270) {
        val t = w; w = h; h = t
      }
      val addedMs = c.getLong(added) * 1000
      val takenMs = if (c.isNull(taken)) 0L else c.getLong(taken)
      return mapOf(
        "id" to c.getLong(id).toString(),
        "type" to if (isVideo) 1 else 0,
        "w" to w,
        "h" to h,
        "dur" to if (isVideo && !c.isNull(duration)) c.getLong(duration) else 0L,
        "ct" to if (takenMs > 0) takenMs else addedMs,
        "mt" to c.getLong(modified) * 1000,
        "ori" to ori,
        "title" to c.getString(name),
        "mime" to c.getString(mime),
        "fav" to (favorite >= 0 && c.getInt(favorite) == 1),
        "live" to false,
      )
    }
  }

  companion object {
    const val ALL_ID = "__all__"

    fun contentUri(id: Long, isVideo: Boolean): Uri = ContentUris.withAppendedId(
      if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
      id,
    )
  }
}
