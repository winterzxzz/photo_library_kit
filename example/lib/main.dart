import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

void main() => runApp(const MaterialApp(home: _Grid()));

class _Grid extends StatefulWidget {
  const _Grid();

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final assets = AssetPagedList();

  @override
  void initState() {
    super.initState();
    PhotoLibrary.requestPermission().then((s) {
      if (s.hasAccess) assets.load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: assets,
      builder: (context, _) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
        itemCount: assets.length,
        itemBuilder: (context, i) {
          final a = assets[i];
          return a == null ? const SizedBox() : AssetThumbnail(asset: a);
        },
      ),
    ),
  );
}
