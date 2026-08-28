import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// In-app pop-up notifications — slide-in banners rendered over ANY screen
/// (home, menu, cart, tracking…), driven by real-time socket events.
/// No permissions needed; works while the app is in the foreground.
class PopupNotifier {
  /// Attach to MaterialApp(navigatorKey: PopupNotifier.navigatorKey).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final ValueNotifier<List<_PopupData>> _queue = ValueNotifier([]);
  static OverlayEntry? _entry;
  static int _counter = 0;

  /// Show a slide-in banner at the top of the screen.
  ///
  /// [onTap]    — runs when the card body is tapped (e.g. open tracking).
  /// [onAction] — runs when the action button is tapped (e.g. Claim).
  static void banner({
    required String title,
    required String message,
    IconData icon = Icons.notifications_rounded,
    Color? color,
    String? actionLabel,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
    VoidCallback? onAction,
    bool sound = false,
  }) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    if (sound) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 350), () => HapticFeedback.mediumImpact());
    }

    final data = _PopupData(
      id: ++_counter,
      title: title,
      message: message,
      icon: icon,
      color: color ?? LuxTheme.primary,
      actionLabel: actionLabel,
      onTap: onTap,
      onAction: onAction,
    );

    // Keep at most 3 popups on screen — drop the oldest.
    final next = [..._queue.value, data];
    if (next.length > 3) next.removeAt(0);
    _queue.value = next;

    Timer(duration, () => _dismiss(data.id));
    _ensureEntry();
  }

  static void _dismiss(int id) {
    _queue.value = _queue.value.where((d) => d.id != id).toList();
  }

  static void _handleTap(_PopupData d) {
    _dismiss(d.id);
    d.onTap?.call();
  }

  static void _handleAction(_PopupData d) {
    _dismiss(d.id);
    d.onAction?.call();
  }

  static void _ensureEntry() {
    if (_entry != null && _entry!.mounted) return;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 8),
          child: ValueListenableBuilder<List<_PopupData>>(
            valueListenable: _queue,
            builder: (context, items, _) => items.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((d) => _PopupCard(
                          data: d,
                          onTap: () => _handleTap(d),
                          onAction: d.actionLabel == null ? null : () => _handleAction(d),
                          onClose: () => _dismiss(d.id),
                        )).toList(),
                  ),
          ),
        ),
      ),
    );
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null) overlay.insert(_entry!);
  }
}

class _PopupData {
  final int id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  _PopupData({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onTap,
    this.onAction,
  });
}

class _PopupCard extends StatelessWidget {
  final _PopupData data;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _PopupCard({
    required this.data,
    required this.onTap,
    required this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -40 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: LuxTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: data.color.withOpacity(0.45)),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: LuxTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (data.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(data.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: LuxTheme.textSecondary,
                              fontSize: 12,
                              height: 1.3)),
                    ],
                    if (onAction != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: onAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: data.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data.actionLabel!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    color: LuxTheme.textSecondary, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
