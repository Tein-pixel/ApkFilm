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
}
