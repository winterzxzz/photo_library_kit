package com.winterzxzz.photo_library_kit

import android.content.ContentResolver
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Watches MediaStore and forwards debounced change events to Dart. Registered
 * only while Dart listens, so idle apps pay nothing.
 */
internal class ChangeObserver(
  private val resolver: ContentResolver,
  private val uris: List<Uri>,
) : EventChannel.StreamHandler {

  private val handler = Handler(Looper.getMainLooper())
  private var sink: EventChannel.EventSink? = null
  private val inserted = LinkedHashSet<String>()
  private val updated = LinkedHashSet<String>()
  private val removed = LinkedHashSet<String>()
  private val flush = Runnable { emit() }

  private val observer = object : ContentObserver(handler) {
    override fun onChange(selfChange: Boolean, uris: Collection<Uri>, flags: Int) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        val target = when {
          flags and ContentResolver.NOTIFY_INSERT != 0 -> inserted
          flags and ContentResolver.NOTIFY_DELETE != 0 -> removed
          else -> updated
        }
        uris.forEach { u -> u.lastPathSegment?.takeIf { s -> s.all(Char::isDigit) }?.let(target::add) }
      }
      schedule()
    }

    override fun onChange(selfChange: Boolean, uri: Uri?) = schedule()
  }

  private fun schedule() {
    handler.removeCallbacks(flush)
    handler.postDelayed(flush, DEBOUNCE_MS)
  }

  private fun emit() {
    // An id inserted and then updated within one window is just an insert.
    updated.removeAll(inserted)
    sink?.success(
      mapOf(
        "inserted" to inserted.toList(),
        "updated" to updated.toList(),
        "removed" to removed.toList(),
      ),
    )
    inserted.clear(); updated.clear(); removed.clear()
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    sink = events
    // Before API 30 MediaProvider only notifies the collection that changed,
    // not the shared files URI.
    uris.forEach { resolver.registerContentObserver(it, true, observer) }
  }

  override fun onCancel(arguments: Any?) {
    resolver.unregisterContentObserver(observer)
    handler.removeCallbacks(flush)
    sink = null
  }

  companion object {
    private const val DEBOUNCE_MS = 300L
  }
}
