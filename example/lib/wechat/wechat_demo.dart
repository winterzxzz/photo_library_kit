import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import 'wechat_picker.dart';
import 'wechat_theme.dart';

/// A Moments-style "new post" composer that opens [WeChatPicker].
class WeChatDemo extends StatefulWidget {
  const WeChatDemo({super.key});

  @override
  State<WeChatDemo> createState() => _WeChatDemoState();
}

class _WeChatDemoState extends State<WeChatDemo> {
  List<MediaAsset> _assets = const [];
  bool _original = false;

  Future<void> _pick() async {
    final result = await WeChatPicker.show(context, initial: _assets);
    if (result == null || !mounted) return;
    setState(() {
      _assets = result.assets;
      _original = result.original;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
        ),
        leadingWidth: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: WeChatSendButton(
              count: _assets.length,
              max: 9,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Posting ${_assets.length} item(s)'
                    '${_original ? ' in original quality' : ''}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextField(
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final a in _assets)
                      GestureDetector(
                        onLongPress: () => setState(
                          () => _assets = [
                            for (final x in _assets)
                              if (x.id != a.id) x,
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AssetThumbnail(asset: a),
                        ),
                      ),
                    if (_assets.length < 9)
                      GestureDetector(
                        onTap: _pick,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 40,
                            color: Color(0xFFB2B2B2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_assets.isNotEmpty)
            Text(
              'Long-press a photo to remove it'
              '${_original ? ' · Original quality' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
