import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineflix_ultra/data/models/media_content.dart';
import 'package:cineflix_ultra/core/server_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerManager', () {
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
