import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'basic/basic_gallery.dart';
import 'instagram/instagram_picker.dart';
import 'wechat/wechat_demo.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'photo_library_kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B5BD6),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF14142B), Color(0xFF2A1B3D), Color(0xFF0F2027)],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              children: [
                const Text(
                  'photo_library_kit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Paged queries, cancellable thumbnails and live updates. '
                  'Pick a demo:',
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 28),
                _DemoCard(
                  title: 'WeChat picker',
                  subtitle:
                      'Dark grid, numbered multi-select, album drop-down, '
                      'swipe preview and "Original" toggle.',
                  icon: Icons.chat_bubble_rounded,
                  colors: const [Color(0xFF07C160), Color(0xFF048A46)],
                  onTap: () => open(const WeChatDemo()),
                ),
                _DemoCard(
                  title: 'Instagram new post',
                  subtitle:
                      'Square crop preview with pinch-to-zoom, '
                      'collapsing grid and multi-select carousel.',
                  icon: Icons.camera_alt_rounded,
                  colors: const [
                    Color(0xFFFEDA75),
                    Color(0xFFD62976),
                    Color(0xFF4F5BD5),
                  ],
                  onTap: () => open(const InstagramPicker()),
                ),
                _DemoCard(
                  title: 'API gallery',
                  subtitle:
                      'Filters, albums, metadata and file access '
                      'with plain Material widgets.',
                  icon: Icons.grid_view_rounded,
                  colors: const [Color(0xFF5B5BD6), Color(0xFF3A3A9E)],
                  onTap: () => open(const BasicGallery()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
