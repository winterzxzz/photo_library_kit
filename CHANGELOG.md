## 0.1.0

Initial release.

* Permission API with full / limited (iOS 14+, Android 14+) states.
* Albums, counts and paged asset queries with native filtering
  (`MediaFilter`: type, date range, video duration, sort).
* `AssetPagedList`: lazy, LRU-cached, self-refreshing list for grids.
* `MediaImageProvider` + `ThumbnailScheduler`: sized native decoding,
  LIFO throttling and native cancellation of off-screen requests.
* `AssetThumbnail` widget with size bucketing and cache-aware fade-in.
* File export, save image/video, delete with system confirmation.
* Debounced change stream with inserted/updated/removed ids.
* Example app with WeChat-style and Instagram-style pickers.
