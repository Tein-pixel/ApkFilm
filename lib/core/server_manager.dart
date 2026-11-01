import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../data/models/media_content.dart';

class ServerDefinition {
  const ServerDefinition({
    required this.id,
    required this.name,
    required this.priority,
    required this.status,
  });
  final String id;
  final String name;
  final int priority;
  final String status;
}

class PlaybackSource {
  const PlaybackSource({
    required this.serverId,
    required this.serverName,
    required this.quality,
    required this.url,
  });
  final String serverId;
  final String serverName;
  final String quality;
  final Uri url;
}

class ServerManager {
  ServerManager({Dio? dio, Future<bool> Function(Uri uri)? probe})
    : _dio = dio ?? Dio(),
      _probeOverride = probe;
  final Dio _dio;
  final Future<bool> Function(Uri uri)? _probeOverride;
  List<ServerDefinition> _servers = const [];
  int _probeTimeoutMs = 2200;
  bool _loaded = false;

  List<ServerDefinition> get servers => List.unmodifiable(_servers);

  Future<void> loadConfig() async {
    if (_loaded) return;
    final decoded =
        jsonDecode(await rootBundle.loadString('assets/config/servers.json'))
            as Map<String, dynamic>;
    _probeTimeoutMs = (decoded['probe_timeout_ms'] as num?)?.toInt() ?? 2200;
    final rows = decoded['servers'];
    if (rows is List) {
      _servers =
          rows
              .whereType<Map>()
              .map((row) {
                final item = Map<String, dynamic>.from(row);
                return ServerDefinition(
                  id: item['id']?.toString() ?? '',
                  name: item['name']?.toString() ?? 'Server',
                  priority: (item['priority'] as num?)?.toInt() ?? 99,
                  status: item['status']?.toString() ?? 'unknown',
                );
              })
              .where((server) => server.id.isNotEmpty)
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));
    }
    if (_servers.length != 5 ||
        _servers.map((server) => server.id).toSet().length != 5) {
      throw const FormatException(
        'Exactly five unique server definitions are required.',
      );
    }
    for (final row in rows as List) {
      if (row is! Map)
        throw const FormatException('Each server must be a JSON object.');
      final qualities = row['qualities'];
      if (qualities is! Map ||
          !['360p', '480p', '720p', '1080p', '4K'].every(qualities.containsKey)) {
        throw const FormatException(
          'Every server must declare 360p, 480p, 720p, 1080p and 4K slots.',
        );
      }
    }
    _loaded = true;
  }

  List<String> qualityFallbackOrder(String preferredQuality) {
    const qualities = ['4K', '1080p', '720p', '480p', '360p'];
    final start = qualities.indexOf(preferredQuality);
    return qualities.sublist(start < 0 ? 1 : start);
  }

  Future<List<PlaybackSource>> getCandidates(
    MediaContent content,
    String preferredQuality, {
    String? preferredServer,
  }) async {
    await loadConfig();
    final order = [..._servers];
    if (preferredServer != null) {
      order.sort((a, b) {
        if (a.id == b.id) return 0;
        if (a.id == preferredServer) return -1;
        if (b.id == preferredServer) return 1;
        return a.priority.compareTo(b.priority);
      });
    }
    final result = <PlaybackSource>[];
    for (final server in order) {
      final source = content.sources[server.id];
      if (source == null) continue;
      final seen = <String>{};
      for (final quality in qualityFallbackOrder(preferredQuality)) {
        final raw = source[quality]?.trim() ?? '';
        final uri = Uri.tryParse(raw);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || !seen.add(raw)) continue;
        result.add(
          PlaybackSource(
            serverId: server.id,
            serverName: server.name,
            quality: quality,
            url: uri,
          ),
        );
      }
    }
    return result;
  }

  Future<PlaybackSource?> getBestSource(
    String contentId,
    String preferredQuality, {
    String? preferredServer,
    required MediaContent content,
  }) async {
    if (content.id != contentId) return null;
    final candidates = await getCandidates(
      content,
      preferredQuality,
      preferredServer: preferredServer,
    );
    for (final source in candidates) {
      if (await isReachable(source.url)) return source;
    }
    return null;
  }

  /// Validate bytes from the origin, not only its HTTP status. This rejects
  /// HTML error/login pages that incorrectly return HTTP 200.
  static bool isPlayablePreview(
    Uri uri,
    String contentType,
    List<int> prefix,
  ) {
    if (prefix.isEmpty) return false;
    final type = contentType.toLowerCase();
    final path = uri.path.toLowerCase();
    final text = utf8
        .decode(prefix, allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trimLeft();

    if (path.endsWith('.m3u8') || type.contains('mpegurl')) {
      return text.startsWith('#EXTM3U');
    }
    if (path.endsWith('.mpd') || type.contains('dash+xml')) {
      return text.contains('<MPD') || text.contains(':MPD');
    }
    if (path.endsWith('.mp4') ||
        path.endsWith('.m4v') ||
        path.endsWith('.mov') ||
        type.contains('video/mp4') ||
        type.contains('video/quicktime')) {
      return prefix.length >= 8 &&
          String.fromCharCodes(prefix.sublist(4, 8)) == 'ftyp';
    }
    if (path.endsWith('.webm') || type.contains('webm')) {
      return prefix.length >= 4 &&
          prefix[0] == 0x1A &&
          prefix[1] == 0x45 &&
          prefix[2] == 0xDF &&
          prefix[3] == 0xA3;
    }
    return false;
  }

  Future<bool> isReachable(Uri uri) async {
    if (_probeOverride != null) return _probeOverride(uri);
    StreamIterator<List<int>>? iterator;
    try {
      final response = await _dio
          .getUri<ResponseBody>(
            uri,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                'Range': 'bytes=0-4095',
                'Accept': '*/*',
                'User-Agent': 'CineWave-Android/7.0',
              },
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 500,
            ),
          )
          .timeout(Duration(milliseconds: _probeTimeoutMs));

      final status = response.statusCode ?? 0;
      if (status < 200 || status > 206 || response.data == null) {
        return false;
      }

      iterator = StreamIterator<List<int>>(response.data!.stream);
      final prefix = <int>[];
      while (prefix.length < 4096 &&
          await iterator.moveNext().timeout(
            Duration(milliseconds: _probeTimeoutMs),
          )) {
        prefix.addAll(iterator.current.take(4096 - prefix.length));
        if (prefix.length >= 16) break;
      }

      final contentType =
          response.headers.value(Headers.contentTypeHeader) ?? '';
      return isPlayablePreview(uri, contentType, prefix);
    } on TimeoutException {
      return false;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    } finally {
      await iterator?.cancel();
    }
  }

  void dispose() => _dio.close(force: true);
}
