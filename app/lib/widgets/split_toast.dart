import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/split_colors.dart';
import 'split_icon.dart';
import '../core/motion/motion_access.dart';

enum SplitToastKind { success, error, info }

enum SplitToastPosition { top, bottom }

/// Split's floating toast, replacing SnackBar app-wide.
///
/// ```dart
/// SplitToast.success(context, 'Copied');
/// // Across an await, grab the handle first (like ScaffoldMessenger.of):
/// final toast = SplitToast.of(context);
/// await save();
/// toast.show('Could not save', kind: SplitToastKind.error);
/// ```
///
/// Lives in the root Overlay, so it survives navigation. A new toast replaces
/// the one showing; each auto-dismisses and can be swiped away.
class SplitToast {
  SplitToast._(this._overlay);
  final OverlayState _overlay;

  static final _hosts = Expando<_ToastHost>();

  static SplitToast of(BuildContext context) =>
      SplitToast._(Overlay.of(context, rootOverlay: true));

  static void success(BuildContext context, String message, {SplitToastAction? action}) =>
      of(context).show(message, kind: SplitToastKind.success, action: action);
  static void error(BuildContext context, String message, {SplitToastAction? action}) =>
      of(context).show(message, kind: SplitToastKind.error, action: action);
  static void info(BuildContext context, String message, {SplitToastAction? action}) =>
      of(context).show(message, kind: SplitToastKind.info, action: action);

  void show(
    String message, {
    SplitToastKind kind = SplitToastKind.info,
    SplitToastAction? action,
    SplitToastPosition position = SplitToastPosition.top,
    Duration? duration,
  }) {
    if (!_overlay.mounted) return;
    final host = _hosts[_overlay] ??= _ToastHost(_overlay);
    host.show(_ToastData(
      message: message,
      kind: kind,
      action: action,
      position: position,
      // Longer for errors and anything with a button to press.
      duration: duration ??
          (action != null || kind == SplitToastKind.error
              ? const Duration(seconds: 5)
              : const Duration(milliseconds: 3200)),
    ));
  }

  /// Removes whatever toast is showing.
  void hide() => _hosts[_overlay]?.hide();
}

class SplitToastAction {
  const SplitToastAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

class _ToastData {
  _ToastData({
    required this.message,
    required this.kind,
    required this.action,
    required this.position,
    required this.duration,
  });
  final String message;
  final SplitToastKind kind;
  final SplitToastAction? action;
  final SplitToastPosition position;
  final Duration duration;
}

class _ToastHost {
  _ToastHost(this.overlay);
  final OverlayState overlay;
  OverlayEntry? _entry;
  Timer? _timer;

  void show(_ToastData data) {
    hide();
    HapticFeedback.lightImpact();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: UniqueKey(),
        data: data,
        onDismiss: () {
          if (_entry == entry) hide();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(data.duration, () {
      if (_entry == entry) hide();
    });
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({super.key, required this.data, required this.onDismiss});
  final _ToastData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = SplitColors.of(context);
    final text = Theme.of(context).textTheme;
    final top = data.position == SplitToastPosition.top;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final (icon, iconColor) = switch (data.kind) {
      SplitToastKind.success => (SplitIcons.checkCircle, c.paidBar),
      SplitToastKind.error => (SplitIcons.alert, c.highlight),
      SplitToastKind.info => (SplitIcons.info, c.accentCyan),
    };

    Widget card = Material(
      color: c.ink,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52, maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.ink.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            SplitIcon(icon, size: 22, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.message,
                style: text.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            if (data.action != null)
              TextButton(
                onPressed: () {
                  onDismiss();
                  data.action!.onPressed();
                },
                style: TextButton.styleFrom(foregroundColor: c.highlight),
                child: Text(data.action!.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );

    card = Semantics(
      liveRegion: true,
      container: true,
      label: data.kind.name,
      child: Dismissible(
        key: const ValueKey('split-toast'),
        direction: top ? DismissDirection.up : DismissDirection.horizontal,
        onDismissed: (_) => onDismiss(),
        child: card,
      ),
    );

    if (!reduceMotion) {
      card = card
          .animate()
          .fadeIn(duration: SplitDurations.short, curve: SplitSprings.gentle)
          .slideY(
            begin: top ? -0.4 : 0.4,
            end: 0,
            duration: SplitDurations.medium,
            curve: SplitSprings.gentle,
          );
    }

    return Positioned(
      left: 16,
      right: 16,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: SafeArea(
        top: top,
        bottom: !top,
        child: Padding(
          padding: EdgeInsets.only(top: top ? 8 : 0, bottom: top ? 0 : 16),
          child: Center(child: KeyedSubtree(key: const Key('split-toast'), child: card)),
        ),
      ),
    );
  }
}
