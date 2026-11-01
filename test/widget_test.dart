import 'package:flutter_test/flutter_test.dart';
import 'package:cineflix_ultra/core/server_manager.dart';

void main() {
  test('quality fallback order steps down without upscaling', () {
    final manager = ServerManager();
    expect(manager.qualityFallbackOrder('4K'), ['4K', '1080p', '720p', '480p']);
    expect(manager.qualityFallbackOrder('1080p'), ['1080p', '720p', '480p']);
    expect(manager.qualityFallbackOrder('720p'), ['720p', '480p']);
    expect(manager.qualityFallbackOrder('480p'), ['480p']);
    manager.dispose();
  });
}
