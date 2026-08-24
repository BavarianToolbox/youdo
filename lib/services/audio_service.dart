import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_repository.dart';

class AudioService {
  AudioService(this._ref) {
    _player = AudioPlayer();
  }

  final Ref _ref;
  late final AudioPlayer _player;

  bool get _enabled {
    final user = _ref.read(currentUserProvider).valueOrNull;
    return user?.soundEnabled ?? true;
  }

  Future<void> playSuccess() async {
    if (!_enabled) return;
    await _player.play(AssetSource('sounds/success.mp3'));
  }

  Future<void> playSoftChime() async {
    if (!_enabled) return;
    await _player.play(AssetSource('sounds/soft_chime.mp3'));
  }

  void dispose() {
    _player.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service.dispose);
  return service;
});
