# photo_library_kit

Fast, ergonomic access to the device photo & video library for Flutter
(Android & iOS): paged queries, cancellable cached thumbnails and live change
streams. It ships with building blocks for real pickers and an example app with
**WeChat-style** and **Instagram-style** pickers.

## Why another photo library plugin?

| | photo_library_kit |
|---|---|
| Scrolling 10k+ assets | `AssetPagedList` fetches only the count up front, then pages of 60 on demand, keeps at most N pages (LRU) and de-duplicates concurrent loads. |
| Thumbnails | Decoded natively **at the requested size**, throttled by a LIFO scheduler (visible cells first), and **cancelled natively** when a cell scrolls away before it loads. |
| Cache keys | Include the modification date, so edited photos never show stale pixels. |
| Live updates | One debounced stream with inserted/updated/removed ids; lists refresh themselves without flicker. |
| Limited access | First-class on iOS 14+ and Android 14+ (`PermissionState.limited`, `presentLimitedPicker`). |
| Filtering | Done in SQL / `NSPredicate`, so only matching rows cross the channel. |

## Install

```yaml
dependencies:
  photo_library_kit: ^0.1.0
```

### Android

The plugin declares `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`,
`READ_MEDIA_VISUAL_USER_SELECTED`, and legacy storage permissions with
`maxSdkVersion`, so you don't need to add anything. Remove the ones you don't
use with `tools:node="remove"`. Google Play restricts `READ_MEDIA_*` to apps
whose core feature is media access.

### iOS

Add to `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick photos and videos to share.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save photos to your library.</string>
<!-- Optional: you show your own "Manage" UI for limited access -->
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

Minimum iOS 15. Both CocoaPods and Swift Package Manager are supported.

## Quick start

```dart
import 'package:photo_library_kit/photo_library_kit.dart';

final state = await PhotoLibrary.requestPermission();
if (!state.hasAccess) return PhotoLibrary.openSettings();

final albums = await PhotoLibrary.getAlbums(filter: MediaFilter.images);
final recent = albums.first;            // the virtual "all" album is first
```

### A smooth grid in ~15 lines

```dart
class Gallery extends StatefulWidget { /* ... */ }

class _GalleryState extends State<Gallery> {
  final assets = AssetPagedList()..load();   // watches library changes too

  @override
  void dispose() { assets.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: assets,
    builder: (context, _) => GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
      itemCount: assets.length,
      itemBuilder: (context, i) {
        final asset = assets[i];             // null while its page loads
        return asset == null ? const ColoredBox(color: Colors.black12)
                             : AssetThumbnail(asset: asset);
      },
    ),
  );
}
```

`AssetThumbnail` picks its pixel size from its layout and the device pixel
ratio, buckets it so neighbouring layouts share cache entries, fades in only
when the image was not cached, and cancels the native request on dispose.

### Full-screen images

```dart
Image(image: MediaImageProvider.preview(asset, longestSide: 2048));
```

Previews are decoded natively with subsampling, so memory scales with the
output size rather than the camera resolution. Show a cached grid thumbnail
underneath (same `ThumbnailOptions`) for an instant placeholder; see
`example/lib/wechat/wechat_preview.dart`.

### Filters

```dart
final filter = MediaFilter(
  types: {MediaType.video},
  minVideoDuration: const Duration(seconds: 3),
  createdAfter: DateTime.now().subtract(const Duration(days: 30)),
  sort: MediaSort.newest,
);
final count = await PhotoLibrary.getAssetCount(filter: filter);
```

### Files, saving, deleting

```dart
final file = await asset.file();                      // display version
final original = await asset.file(original: true);    // unedited original
await PhotoLibrary.saveImage(bytes, filename: 'edit.jpg');
await PhotoLibrary.saveVideo('/path/clip.mp4');
final deleted = await PhotoLibrary.deleteAssets([asset]); // system confirms
await PhotoLibrary.clearFileCache();                  // iOS exports
```

### Changes

```dart
final sub = PhotoLibrary.changes.listen((change) {
  print('${change.insertedIds.length} new');
});
```

The native observer runs only while the stream has listeners.

## Example app

`example/` contains:

* **WeChat picker**: dark grid, numbered multi-select (max 9), album
  drop-down, swipe/zoom preview with a selection strip, and an "Original"
  toggle. It feeds a Moments-style composer.
* **Instagram new post**: square crop preview with pinch-to-zoom and a
  rule-of-thirds overlay, pinned album header, multi-select (max 10) and a
  carousel share page.
* **API gallery**: filters, albums, metadata and file access.

## Platform notes

* Android sorts by `DATE_ADDED`; iOS by `creationDate`.
* `MediaFilter.includeGifs` is Android-only (PhotoKit has no predicate for it).
* iOS returns `title`/`mimeType` from `getAsset` only. They need a slower
  resource lookup that paging skips for speed.
* Android 10 can only delete media the app owns, unless the user grants
  per-item consent.

## Testing

Swap the platform with a fake:

```dart
PhotoLibraryPlatform.instance = MyFakePlatform();
```

See `test/fake_platform.dart`.
