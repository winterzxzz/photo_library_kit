package com.winterzxzz.photo_library_kit

import android.provider.MediaStore

/** Native mirror of the Dart `MediaFilter`, compiled to a SQL selection. */
internal class MediaFilter(
  val image: Boolean,
  val video: Boolean,
  val sort: Int,
  val after: Long?,
  val before: Long?,
  val minDuration: Long?,
  val maxDuration: Long?,
  val includeGifs: Boolean,
) {
  val orderBy: String
    get() = when (sort) {
      SORT_OLDEST -> "${MediaStore.MediaColumns.DATE_ADDED} ASC, ${MediaStore.MediaColumns._ID} ASC"
      SORT_MODIFIED -> "${MediaStore.MediaColumns.DATE_MODIFIED} DESC, ${MediaStore.MediaColumns._ID} DESC"
      else -> "${MediaStore.MediaColumns.DATE_ADDED} DESC, ${MediaStore.MediaColumns._ID} DESC"
    }

  /** Builds the WHERE clause and its arguments, optionally scoped to a bucket. */
  fun selection(bucketId: String?): Pair<String, Array<String>> {
    val clauses = mutableListOf<String>()
    val args = mutableListOf<String>()
    val type = MediaStore.Files.FileColumns.MEDIA_TYPE

    val videoClause = buildString {
      append("$type = ${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO}")
      if (minDuration != null) append(" AND $COL_DURATION >= $minDuration")
      if (maxDuration != null) append(" AND $COL_DURATION <= $maxDuration")
    }
    val imageClause = buildString {
      append("$type = ${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}")
      if (!includeGifs) append(" AND ${MediaStore.MediaColumns.MIME_TYPE} != 'image/gif'")
    }
    clauses += when {
      image && video -> "(($imageClause) OR ($videoClause))"
      image -> "($imageClause)"
      video -> "($videoClause)"
      else -> "0"
    }
    if (after != null) {
      clauses += "${MediaStore.MediaColumns.DATE_ADDED} >= ?"
      args += (after / 1000).toString()
    }
    if (before != null) {
      clauses += "${MediaStore.MediaColumns.DATE_ADDED} <= ?"
      args += (before / 1000).toString()
    }
    if (bucketId != null) {
      clauses += "$COL_BUCKET_ID = ?"
      args += bucketId
    }
    clauses += "${MediaStore.MediaColumns.SIZE} > 0"
    return clauses.joinToString(" AND ") to args.toTypedArray()
  }

  companion object {
    const val SORT_OLDEST = 1
    const val SORT_MODIFIED = 2

    // Raw column names that exist in the files table on every API level.
    const val COL_DURATION = "duration"
    const val COL_BUCKET_ID = "bucket_id"
    const val COL_BUCKET_NAME = "bucket_display_name"
    const val COL_ORIENTATION = "orientation"
    const val COL_DATE_TAKEN = "datetaken"

    fun from(map: Map<*, *>?): MediaFilter {
      val m = map ?: emptyMap<String, Any?>()
      return MediaFilter(
        image = m["image"] as? Boolean ?: true,
        video = m["video"] as? Boolean ?: true,
        sort = (m["sort"] as? Number)?.toInt() ?: 0,
        after = (m["after"] as? Number)?.toLong(),
        before = (m["before"] as? Number)?.toLong(),
        minDuration = (m["minDur"] as? Number)?.toLong(),
        maxDuration = (m["maxDur"] as? Number)?.toLong(),
        includeGifs = m["gif"] as? Boolean ?: true,
      )
    }
  }
}
