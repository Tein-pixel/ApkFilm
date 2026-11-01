import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineflix_ultra/data/models/media_content.dart';
import 'package:cineflix_ultra/core/server_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerManager', () {
    test('playback probe validates HLS, DASH, MP4 and WebM signatures', () {
      expect(
        ServerManager.isPlayablePreview(
          Uri.parse('https://media.example/movie/index.m3u8'),
          'application/vnd.apple.mpegurl',
          '#EXTM3U\n#EXT-X-VERSION:3'.codeUnits,
        ),
        isTrue,
      );
      expect(
        ServerManager.isPlayablePreview(
          Uri.parse('https://media.example/movie/index.m3u8'),
          'text/html',
          '<html><body>Access denied</body></html>'.codeUnits,
        ),
        isFalse,
      );
      expect(
        ServerManager.isPlayablePreview(
          Uri.parse('https://media.example/movie/file.mp4'),
          'video/mp4',
          [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0, 0, 0, 0],
        ),
        isTrue,
      );
      expect(
        ServerManager.isPlayablePreview(
          Uri.parse('https://media.example/movie/manifest.mpd'),
          'application/dash+xml',
          '<?xml version="1.0"?><MPD'.codeUnits,
        ),
        isTrue,
      );
      expect(
        ServerManager.isPlayablePreview(
          Uri.parse('https://media.example/movie/file.webm'),
          'video/webm',
          [0x1A, 0x45, 0xDF, 0xA3, 0, 0, 0, 0],
        ),
        isTrue,
      );
    });


    test('quality fallback starts at the selected quality and steps down', () {
      final manager = ServerManager();
      expect(manager.qualityFallbackOrder('1080p'), ['1080p', '720p', '480p']);
      expect(manager.qualityFallbackOrder('4K'), [
        '4K',
        '1080p',
        '720p',
        '480p',
      ]);
      expect(manager.qualityFallbackOrder('720p'), ['720p', '480p']);
      expect(manager.qualityFallbackOrder('480p'), ['480p']);
      manager.dispose();
    });

    test(
      'loads exactly five configured server slots with four quality slots each',
      () async {
        final manager = ServerManager();
        await manager.loadConfig();
        expect(manager.servers, hasLength(5));
        expect(manager.servers.map((s) => s.priority).toList(), [
          1,
          2,
          3,
          4,
          5,
        ]);
        final config =
            jsonDecode(
                  await rootBundle.loadString('assets/config/servers.json'),
                )
                as Map<String, dynamic>;
        for (final server in config['servers'] as List) {
          expect(
            (server as Map)['qualities'].keys,
            containsAll(['480p', '720p', '1080p', '4K']),
          );
        }
        manager.dispose();
      },
    );

    test(
      'catalogue titles expose five server maps and ordered playable candidates',
      () async {
        final raw =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/database/all_content.json',
                  ),
                )
                as List;
        final contents = raw
            .map(
              (row) =>
                  MediaContent.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        for (final content in contents) {
          expect(
            content.sources.keys,
            containsAll([
              'server1',
              'server2',
              'server3',
              'server4',
              'server5',
            ]),
          );
          for (final server in content.sources.values) {
            expect(server.keys, containsAll(['480p', '720p', '1080p', '4K']));
          }
        }
        final manager = ServerManager(probe: (_) async => true);
        final candidates = await manager.getCandidates(contents.first, '1080p');
        expect(candidates, isNotEmpty);
        expect(candidates.first.serverId, 'server1');
        expect(candidates.first.url.toString(), contains('test-streams.mux.dev'));
        for (final content in contents) {
          final playable = await manager.getCandidates(content, '720p');
          expect(
            playable,
            isNotEmpty,
            reason: '${content.title} must have at least one configured licensed source.',
          );
          expect(
            content.poster,
            startsWith('https://'),
            reason: '${content.title} must have real poster artwork.',
          );
        }
        manager.dispose();
      },
    );
  });
}
