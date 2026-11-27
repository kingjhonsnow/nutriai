import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Records app usage for the admin's activity view:
///  * when a signed-in user opens the app or comes back to it,
///  * every 5 minutes while the app stays on screen (this measures time spent).
/// The database groups pings into "sessions": a break of more than 15 minutes
/// starts a new one, so "opened 3 times today" means 3 separate visits.
/// Tracking never shows errors or slows the app down.
class ActivityTracker extends ConsumerStatefulWidget {
  final Widget child;

  const ActivityTracker({super.key, required this.child});

  @override
  ConsumerState<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends ConsumerState<ActivityTracker> with WidgetsBindingObserver {
  static const Duration _heartbeatEvery = Duration(minutes: 5);

  Timer? _heartbeat;
  DateTime? _lastPing;
  bool _sending = false;

  static String get _platform => '${kIsWeb ? 'web' : 'app'}-${defaultTargetPlatform.name}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ping(force: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      _ping(force: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _heartbeat?.cancel();
      _heartbeat = null;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _ping());
  }

  Future<void> _ping({bool force = false}) async {
    if (!mounted || _sending) return;
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.signedIn || auth.userId == null) return;

    final now = DateTime.now();
    final last = _lastPing;
    if (last != null) {
      final gap = now.difference(last);
      if (gap < const Duration(seconds: 30)) return; // several events at once
      if (!force && gap < const Duration(minutes: 4)) return;
    }

    _sending = true;
    _lastPing = now;
    try {
      await ref.read(supabaseClientProvider).rpc(
        'track_app_activity',
        params: {'p_platform': _platform},
      );
    } catch (_) {
      // Tracking is best effort and must never disturb the user.
    } finally {
      _sending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Count a visit as soon as someone signs in (or switches account).
    ref.listen<String>(
      authProvider.select((s) => '${s.status.name}|${s.userId}'),
      (previous, next) {
        if (next != previous && next.startsWith('${AuthStatus.signedIn.name}|')) {
          _lastPing = null;
          _ping(force: true);
        }
      },
    );
    return widget.child;
  }
}
