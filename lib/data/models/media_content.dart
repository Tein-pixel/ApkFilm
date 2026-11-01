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
  final Map<String, Map<String, String>> sources;

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
      sources: parsedSources,
    );
  }
}
