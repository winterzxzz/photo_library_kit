import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

/// Requests library access once and shows a friendly explanation when it is
/// missing. [builder] runs only with full or limited access.
class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.builder,
    this.foreground = Colors.white,
    this.accent = const Color(0xFF07C160),
  });

  final Widget Function(BuildContext context, PermissionState state) builder;
  final Color foreground;
  final Color accent;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  PermissionState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _request();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Returning from Settings may have changed the permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !(_state?.hasAccess ?? false)) {
      PhotoLibrary.getPermissionState().then(_set);
    }
  }

  Future<void> _request() async => _set(await PhotoLibrary.requestPermission());

  void _set(PermissionState s) {
    if (mounted && s != _state) setState(() => _state = s);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.expand();
    if (state.hasAccess) return widget.builder(context, state);
    final fg = widget.foreground;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: fg),
            const SizedBox(height: 16),
            Text(
              'Allow access to your photos',
              style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose photos and videos to share. You can allow all or '
              'only selected items.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              onPressed: state == PermissionState.notDetermined
                  ? _request
                  : PhotoLibrary.openSettings,
              child: Text(
                state == PermissionState.notDetermined
                    ? 'Continue'
                    : 'Open Settings',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You've allowed access to selected items" banner with a Manage action.
class LimitedAccessBanner extends StatelessWidget {
  const LimitedAccessBanner({
    super.key,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'You can only see the photos you selected.',
                style: TextStyle(color: foreground, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: PhotoLibrary.presentLimitedPicker,
              child: Text('Manage', style: TextStyle(color: accent)),
            ),
          ],
        ),
      ),
    );
  }
}
