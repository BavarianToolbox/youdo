import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_repository.dart';

class HapticsService {
  HapticsService(this._ref);

  final Ref _ref;

  bool get _enabled {
    final user = _ref.read(currentUserProvider).valueOrNull;
    return user?.hapticsEnabled ?? true;
  }

  Future<void> successPattern() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  Future<void> lightTap() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> errorPattern() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }
}

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  return HapticsService(ref);
});
