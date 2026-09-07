import 'dart:async';
import 'package:flutter/material.dart';
import 'body_media.dart';

MaterialPageRoute<T> bodyRoute<T>(
  BodyMediaStore media,
  WidgetBuilder builder,
) => MaterialPageRoute<T>(
  builder: (context) => BodyPrivacyGate(media: media, child: builder(context)),
);

/// Each private route is obscured after backgrounding, including editors and
/// the final share preview. FLAG_SECURE also hides sensitive task snapshots.
class BodyPrivacyGate extends StatefulWidget {
  const BodyPrivacyGate({super.key, required this.media, required this.child});
  final BodyMediaStore media;
  final Widget child;
  @override
  State<BodyPrivacyGate> createState() => _BodyPrivacyGateState();
}

class _BodyPrivacyGateState extends State<BodyPrivacyGate>
    with WidgetsBindingObserver {
  static int protectedRoutes = 0;
  bool protected = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.media.addListener(refresh);
    refresh();
  }

  void refresh() {
    final enabled = widget.media.lockEnabled;
    if (enabled != protected) {
      protectedRoutes += enabled ? 1 : -1;
      protected = enabled;
      unawaited(
        widget.media
            .protectScreen(protectedRoutes > 0)
            .catchError((Object _) {}),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.media.lockEnabled) {
      widget.media.relock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.media.removeListener(refresh);
    if (protected) {
      protectedRoutes--;
      unawaited(
        widget.media
            .protectScreen(protectedRoutes > 0)
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(
        offstage: widget.media.lockEnabled && !widget.media.sessionUnlocked,
        child: widget.child,
      ),
      if (widget.media.lockEnabled && !widget.media.sessionUnlocked)
        Positioned.fill(
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 36),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                await widget.media.unlock();
                              } on Object {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Device authentication is unavailable. Set up a screen lock and try again.',
                                      ),
                                    ),
                                  );
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: const Text('Open body progress'),
                    ),
                    if (Navigator.canPop(context))
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
