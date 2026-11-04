package com.winterzxzz.photo_library_kit

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.PluginRegistry

/** Maps Android runtime permissions onto the Dart `PermissionState` indexes. */
internal class PermissionManager(private val context: Context) :
  PluginRegistry.RequestPermissionsResultListener {

  private var pending: ((Int) -> Unit)? = null
  private var pendingWanted: List<String> = emptyList()
  private val prefs = context.getSharedPreferences("photo_library_kit", Context.MODE_PRIVATE)

  fun permissionsFor(images: Boolean, videos: Boolean): List<String> = when {
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> buildList {
      if (images) add(Manifest.permission.READ_MEDIA_IMAGES)
      if (videos) add(Manifest.permission.READ_MEDIA_VIDEO)
    }
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    else -> listOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
  }

  fun state(wanted: List<String>): Int {
    if (wanted.all(::granted)) return AUTHORIZED
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
      granted(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
    ) return LIMITED
    return if (prefs.getBoolean(KEY_ASKED, false)) DENIED else NOT_DETERMINED
  }

  fun request(activity: Activity?, wanted: List<String>, done: (Int) -> Unit) {
    val current = state(wanted)
    if (current == AUTHORIZED) return done(current)
    if (activity == null || pending != null) return done(current)
    val toRequest = wanted.toMutableList()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      // Required so the system offers "Select photos" instead of all-or-nothing.
      toRequest += Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
    }
    pending = done
    pendingWanted = wanted
    prefs.edit().putBoolean(KEY_ASKED, true).apply()
    activity.requestPermissions(toRequest.toTypedArray(), REQUEST_CODE)
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ): Boolean {
    if (requestCode != REQUEST_CODE) return false
    val cb = pending ?: return true
    pending = null
    cb(state(pendingWanted))
    return true
  }

  private fun granted(p: String) =
    context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

  companion object {
    const val NOT_DETERMINED = 0
    const val DENIED = 2
    const val AUTHORIZED = 3
    const val LIMITED = 4
    private const val REQUEST_CODE = 0x5048
    private const val KEY_ASKED = "asked"
  }
}
