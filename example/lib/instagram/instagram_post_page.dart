import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

/// The step after picking: carousel, caption and share.
class InstagramPostPage extends StatefulWidget {
  const InstagramPostPage({
    super.key,
    required this.assets,
    required this.fill,
  });

  final List<MediaAsset> assets;
  final bool fill;

  @override
  State<InstagramPostPage> createState() => _InstagramPostPageState();
}

class _InstagramPostPageState extends State<InstagramPostPage> {
  final ValueNotifier<int> _page = ValueNotifier(0);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side =
        (math.max(size.width, size.height) *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'New post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: widget.assets.length,
              onPageChanged: (i) => _page.value = i,
              itemBuilder: (context, i) => Image(
                image: MediaImageProvider.preview(
                  widget.assets[i],
                  longestSide: side,
                ),
                fit: widget.fill ? BoxFit.cover : BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (widget.assets.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.assets.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == page ? 7 : 6,
                        height: i == page ? 7 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == page
                              ? const Color(0xFF0095F6)
                              : Colors.white24,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(color: Colors.white12),
          for (final (icon, label) in const [
            (Icons.person_outline, 'Tag people'),
            (Icons.location_on_outlined, 'Add location'),
            (Icons.music_note_outlined, 'Add music'),
          ])
            ListTile(
              leading: Icon(icon, color: Colors.white),
              title: Text(label, style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0095F6),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Shared ${widget.assets.length} item(s)'),
                ),
              );
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text(
              'Share',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
