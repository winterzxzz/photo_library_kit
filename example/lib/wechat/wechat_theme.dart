import 'package:flutter/material.dart';

abstract final class WeChatColors {
  static const green = Color(0xFF07C160);
  static const background = Color(0xFF111111);
  static const bar = Color(0xF21A1A1A);
  static const tile = Color(0xFF222222);
  static const text = Colors.white;
  static const secondary = Color(0x99FFFFFF);
  static const divider = Color(0x1FFFFFFF);
}

/// Green rounded "Send (2/9)" button.
class WeChatSendButton extends StatelessWidget {
  const WeChatSendButton({
    super.key,
    required this.count,
    required this.max,
    required this.onPressed,
  });

  final int count;
  final int max;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0 && onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: WeChatColors.green,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              count > 0 ? 'Send ($count/$max)' : 'Send',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round checkbox that shows the selection order number.
class WeChatCheck extends StatelessWidget {
  const WeChatCheck({super.key, required this.index, this.size = 24});

  /// 0-based selection index, or -1 when not selected.
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final selected = index >= 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? WeChatColors.green : Colors.black26,
        border: selected ? null : Border.all(color: Colors.white, width: 1.5),
      ),
      child: selected
          ? Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
