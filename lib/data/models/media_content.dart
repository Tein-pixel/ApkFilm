class MediaContent {
  const MediaContent({
    required this.id,
    required this.title,
    required this.type,
    required this.categories,
    required this.year,
    required this.rating,
    required this.age,
    required this.duration,
    required this.status,
    required this.synopsis,
    required this.license,
    required this.attribution,
    required this.sources,
    this.poster,
    this.backdrop,
    this.tmdbId,
    this.subtitles = const {},
  });

  final String id;
  final String title;
  final String type;
  final List<String> categories;
  final int year;
  final double rating;
  final String age;
  final String duration;
  final String status;
  final String synopsis;
  final String license;
  final String attribution;
  final String? poster;
  final String? backdrop;
  final int? tmdbId;
  final Map<String, Map<String, String>> sources;
  /// External WebVTT subtitle tracks keyed by display language/name.
  final Map<String, String> subtitles;

  bool get isTmdb => tmdbId != null;
  bool get isMovie => type == 'movie';
  bool get hasPlayableSource => sources.values.any(
    (source) => source.values.any((value) {
      final uri = Uri.tryParse(value.trim());
      return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    }),
  );

  MediaContent mergeCategories(MediaContent other) => MediaContent(
    id: id,
    title: title,
    type: type,
    categories: <String>{...categories, ...other.categories}.toList(),
    year: year,
    rating: rating,
    age: age,
    duration: duration,
    status: status,
    synopsis: synopsis,
    license: license,
    attribution: attribution,
    poster: poster,
    backdrop: backdrop,
    tmdbId: tmdbId,
    sources: sources,
    subtitles: subtitles,
  );

  factory MediaContent.fromTmdb(
    Map<String, dynamic> json, {
    String? mediaTypeOverride,
    String? categoryLabel,
  }) {
    final mediaType = mediaTypeOverride ??
        json['media_type']?.toString() ??
        (json.containsKey('title') ? 'movie' : 'tv');
    if (mediaType != 'movie' && mediaType != 'tv') {
      throw const FormatException('TMDB result is not a movie or TV title.');
    }
    final tmdbId = (json['id'] as num?)?.toInt();
    if (tmdbId == null || tmdbId <= 0) {
      throw const FormatException('TMDB title is missing a valid ID.');
    }

    const genreNames = <int, String>{
      12: 'Adventure', 14: 'Fantasy', 16: 'Animation', 18: 'Drama',
      27: 'Horror', 28: 'Action', 35: 'Comedy', 36: 'History',
      37: 'Western', 53: 'Thriller', 80: 'Crime', 99: 'Documentary',
      878: 'Science Fiction', 9648: 'Mystery', 10402: 'Music',
      10749: 'Romance', 10751: 'Family', 10752: 'War',
      10759: 'Action & Adventure', 10762: 'Kids', 10763: 'News',
      10764: 'Reality', 10765: 'Sci-Fi & Fantasy', 10766: 'Soap',
      10767: 'Talk', 10768: 'War & Politics',
    };
    final categories = <String>{};
    final rawGenres = json['genre_ids'];
    final genreIds = <int>{};
    if (rawGenres is List) {
      for (final genre in rawGenres) {
        final id = genre is num ? genre.toInt() : int.tryParse('$genre');
        if (id != null) {
          genreIds.add(id);
          final name = genreNames[id];
          if (name != null) categories.add(name);
        }
      }
    }

    final originalLanguage = json['original_language']?.toString() ?? '';
    final rawCountries = json['origin_country'];
    final countries = rawCountries is List
        ? rawCountries.map((value) => value.toString()).toSet()
        : <String>{};
    const regionalDramaLabels = <String, String>{
      'KR': 'K-Drama',
      'CN': 'C-Drama',
      'TH': 'Thai Drama',
      'TW': 'Taiwanese Drama',
      'ID': 'Indonesian Drama',
      'PH': 'Filipino Drama',
      'IN': 'Indian Drama',
      'JP': 'Japanese Drama',
    };
    if (mediaType == 'tv' && genreIds.contains(18)) {
      for (final country in countries) {
        final label = regionalDramaLabels[country];
        if (label != null) categories.add(label);
      }
    }
    if (genreIds.contains(16) &&
        (originalLanguage == 'ja' || countries.contains('JP'))) {
      categories.add('Anime');
    }
    if (categoryLabel != null && categoryLabel.isNotEmpty) {
      categories.add(categoryLabel);
    }

    final rawDate = (mediaType == 'movie'
        ? json['release_date']
        : json['first_air_date'])?.toString() ?? '';
    final year = rawDate.length >= 4
        ? int.tryParse(rawDate.substring(0, 4)) ?? 0
        : 0;
    final title = (mediaType == 'movie'
        ? json['title'] ?? json['original_title']
        : json['name'] ?? json['original_name'])?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('TMDB title has no display name.');
    }
    String? imageUrl(String? path, String size) {
      if (path == null || path.trim().isEmpty) return null;
      return 'https://image.tmdb.org/t/p/$size${path.trim()}';
    }

    return MediaContent(
      id: 'tmdb:$mediaType:$tmdbId',
      title: title,
      type: mediaType,
      categories: categories.toList(growable: false),
      year: year,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0,
      age: 'NR',
      duration: mediaType == 'movie' ? 'Film' : 'Series',
      status: mediaType == 'movie' ? 'Movie' : 'TV Series',
      synopsis: json['overview']?.toString() ?? '',
      license: 'TMDB metadata and artwork',
      attribution: 'This product uses the TMDB API but is not endorsed or certified by TMDB.',
      poster: imageUrl(json['poster_path']?.toString(), 'w500'),
      backdrop: imageUrl(json['backdrop_path']?.toString(), 'w1280'),
      tmdbId: tmdbId,
      sources: const {},
      subtitles: const {},
    );
  }

  factory MediaContent.fromJson(Map<String, dynamic> json) {
    final parsedSources = <String, Map<String, String>>{};
    final rawSources = json['sources'];
    if (rawSources is Map) {
      for (final entry in rawSources.entries) {
        if (entry.value is Map) {
          parsedSources[entry.key.toString()] = (entry.value as Map).map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          );
        }
      }
    }
    final rawSubtitles = json['subtitles'];
    final parsedSubtitles = rawSubtitles is Map
        ? rawSubtitles.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
        : <String, String>{};
    final rawCategories = json['categories'];
    return MediaContent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      type: json['type']?.toString() ?? 'movie',
      categories: rawCategories is List
          ? rawCategories.map((e) => e.toString()).toList(growable: false)
          : const [],
      year: (json['year'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      age: json['age']?.toString() ?? 'NR',
      duration: json['duration']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Unknown',
      synopsis: json['synopsis']?.toString() ?? '',
      license: json['license']?.toString() ?? 'License not specified',
      attribution: json['attribution']?.toString() ?? '',
      poster: json['poster']?.toString(),
      backdrop: json['backdrop']?.toString(),
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      sources: parsedSources,
      subtitles: parsedSubtitles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'type': type, 'categories': categories,
    'year': year, 'rating': rating, 'age': age, 'duration': duration,
    'status': status, 'synopsis': synopsis, 'license': license,
    'attribution': attribution, 'poster': poster, 'backdrop': backdrop,
    'tmdbId': tmdbId, 'sources': sources, 'subtitles': subtitles,
  };
}
