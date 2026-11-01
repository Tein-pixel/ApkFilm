import 'package:dio/dio.dart';
import '../models/media_content.dart';

/// Read-only TMDB integration for catalogue metadata and regional provider links.
class TmdbService {
  TmdbService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.themoviedb.org/3',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 12),
                headers: const {'accept': 'application/json'},
              ),
            );

  final Dio _dio;
  static const String _apiKey = String.fromEnvironment('TMDB_API_KEY2');
  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Map<String, dynamic> get _authParams => {'api_key': _apiKey};

  Future<List<MediaContent>> _fetchList(
    String path, {
    String? mediaType,
    String? category,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!isConfigured) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          ..._authParams,
          'language': 'id-ID',
          'page': 1,
          'include_adult': false,
          ...extra,
        },
      );
      final rows = response.data?['results'];
      if (rows is! List) return const [];
      final items = <MediaContent>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final raw = Map<String, dynamic>.from(row);
        final kind = mediaType ?? raw['media_type']?.toString();
        if (kind != 'movie' && kind != 'tv') continue;
        try {
          items.add(
            MediaContent.fromTmdb(
              raw,
              mediaTypeOverride: kind,
              categoryLabel: category,
            ),
          );
        } on FormatException {
          continue;
        }
      }
      return items;
    } catch (_) {
      // One failed discovery feed must not suppress all other catalogue feeds.
      return const [];
    }
  }

  Future<List<MediaContent>> loadHomeCatalog() async {
    if (!isConfigured) return const [];
    final groups = await Future.wait([
      _fetchList('/trending/all/week'),
      _fetchList('/movie/popular', mediaType: 'movie', category: 'Movies'),
      _fetchList('/tv/popular', mediaType: 'tv', category: 'Series'),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'K-Drama',
        extra: {'with_origin_country': 'KR', 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'C-Drama',
        extra: {'with_origin_country': 'CN', 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Thai Drama',
        extra: {'with_origin_country': 'TH', 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Taiwanese Drama',
        extra: {'with_origin_country': 'TW', 'with_genres': 18, 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Indonesian Drama',
        extra: {'with_origin_country': 'ID', 'with_genres': 18, 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Filipino Drama',
        extra: {'with_origin_country': 'PH', 'with_genres': 18, 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Indian Drama',
        extra: {'with_origin_country': 'IN', 'with_genres': 18, 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Japanese Drama',
        extra: {'with_origin_country': 'JP', 'with_genres': 18, 'sort_by': 'popularity.desc'},
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Anime',
        extra: {
          'with_origin_country': 'JP',
          'with_genres': 16,
          'sort_by': 'popularity.desc',
        },
      ),
      _fetchList(
        '/discover/movie',
        mediaType: 'movie',
        category: 'Anime',
        extra: {
          'with_original_language': 'ja',
          'with_genres': 16,
          'sort_by': 'popularity.desc',
        },
      ),
    ]);

    final merged = <String, MediaContent>{};
    for (final group in groups) {
      for (final item in group) {
        final old = merged[item.id];
        merged[item.id] = old == null ? item : old.mergeCategories(item);
      }
    }
    return merged.values.take(180).toList(growable: false);
  }

  Future<List<MediaContent>> searchMulti(String query, {int page = 1}) async {
    final clean = query.trim();
    if (!isConfigured || clean.isEmpty) return const [];
    return _fetchList(
      '/search/multi',
      extra: {'query': clean, 'include_adult': false, 'page': page.clamp(1, 500)},
    );
  }


  /// Fetches full movie/TV metadata, cast, trailers and local age ratings.
  /// This endpoint never returns an authorized full-length movie stream.
  Future<Map<String, dynamic>?> getTitleDetails(MediaContent content) async {
    if (!isConfigured || !content.isTmdb || content.tmdbId == null) {
      return null;
    }
    final append = content.type == 'movie'
        ? 'credits,videos,release_dates'
        : 'credits,videos,content_ratings';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/${content.type}/${content.tmdbId}',
        queryParameters: {
          ..._authParams,
          'language': 'id-ID',
          'append_to_response': append,
        },
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  /// Provider information is region-specific and is not a video stream.
  Future<Map<String, dynamic>?> getWatchProviders(MediaContent content) async {
    if (!isConfigured || !content.isTmdb || content.tmdbId == null) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/${content.type}/${content.tmdbId}/watch/providers',
        queryParameters: _authParams,
      );
      final results = response.data?['results'];
      if (results is! Map) return null;
      final indonesia = results['ID'];
      if (indonesia is! Map) return null;
      return Map<String, dynamic>.from(indonesia);
    } catch (_) {
      return null;
    }
  }

  /// Loads one season's episode metadata. TMDB provides metadata only; it
  /// does not provide episode video streams.
  Future<Map<String, dynamic>?> getTvSeasonDetails(
    MediaContent content,
    int seasonNumber,
  ) async {
    if (!isConfigured || content.type != 'tv' || content.tmdbId == null ||
        seasonNumber < 0) {
      return null;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tv/${content.tmdbId}/season/$seasonNumber',
        queryParameters: {..._authParams, 'language': 'id-ID'},
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  /// Returns official Indonesian streaming providers listed by TMDB.
  /// Provider listings are availability data and never represent stream URLs.
  Future<List<Map<String, dynamic>>> getIndonesiaProviders() async {
    if (!isConfigured) return const [];
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '/watch/providers/movie',
          queryParameters: {..._authParams, 'watch_region': 'ID', 'language': 'id-ID'},
        ),
        _dio.get<Map<String, dynamic>>(
          '/watch/providers/tv',
          queryParameters: {..._authParams, 'watch_region': 'ID', 'language': 'id-ID'},
        ),
      ]);
      final byId = <int, Map<String, dynamic>>{};
      for (final response in responses) {
        final rows = response.data?['results'];
        if (rows is! List) continue;
        for (final row in rows.whereType<Map>()) {
          final provider = Map<String, dynamic>.from(row);
          final id = (provider['provider_id'] as num?)?.toInt();
          if (id != null && id > 0) byId.putIfAbsent(id, () => provider);
        }
      }
      final result = byId.values.toList();
      result.sort((a, b) =>
          ((a['display_priority'] as num?)?.toInt() ?? 999)
              .compareTo((b['display_priority'] as num?)?.toInt() ?? 999));
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// Finds titles available from an official provider in Indonesia.
  Future<List<MediaContent>> discoverByProvider(int providerId) async {
    if (!isConfigured || providerId <= 0) return const [];
    final groups = await Future.wait([
      _fetchList(
        '/discover/movie',
        mediaType: 'movie',
        category: 'Movies',
        extra: {
          'watch_region': 'ID',
          'with_watch_providers': providerId,
          'sort_by': 'popularity.desc',
        },
      ),
      _fetchList(
        '/discover/tv',
        mediaType: 'tv',
        category: 'Series',
        extra: {
          'watch_region': 'ID',
          'with_watch_providers': providerId,
          'sort_by': 'popularity.desc',
        },
      ),
    ]);
    final merged = <String, MediaContent>{};
    for (final group in groups) {
      for (final item in group) {
        final old = merged[item.id];
        merged[item.id] = old == null ? item : old.mergeCategories(item);
      }
    }
    return merged.values.toList(growable: false);
  }

}
