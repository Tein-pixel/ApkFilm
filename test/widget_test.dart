import 'package:flutter_test/flutter_test.dart';
import 'package:cineflix_ultra/core/server_manager.dart';
import 'package:cineflix_ultra/data/models/media_content.dart';

void main() {
  test('quality fallback order steps down without upscaling', () {
    final manager = ServerManager();
    expect(manager.qualityFallbackOrder('4K'), ['4K', '1080p', '720p', '480p', '360p']);
    expect(manager.qualityFallbackOrder('1080p'), ['1080p', '720p', '480p', '360p']);
    expect(manager.qualityFallbackOrder('720p'), ['720p', '480p', '360p']);
    expect(manager.qualityFallbackOrder('480p'), ['480p', '360p']);
    expect(manager.qualityFallbackOrder('360p'), ['360p']);
    manager.dispose();
  });

  test('TMDB movie and TV results map without inventing video sources', () {
    final movie = MediaContent.fromTmdb({
      'id': 550,
      'media_type': 'movie',
      'title': 'Example Film',
      'release_date': '2024-01-01',
      'overview': 'Movie overview',
      'poster_path': '/poster.jpg',
      'backdrop_path': '/backdrop.jpg',
      'vote_average': 8.2,
      'genre_ids': [18, 878],
    });
    expect(movie.id, 'tmdb:movie:550');
    expect(movie.isTmdb, isTrue);
    expect(movie.type, 'movie');
    expect(movie.year, 2024);
    expect(movie.poster, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(movie.sources, isEmpty);
    expect(movie.categories, contains('Drama'));

    final series = MediaContent.fromTmdb({
      'id': 123,
      'media_type': 'tv',
      'name': 'Example Drama',
      'first_air_date': '2022-05-01',
      'genre_ids': [18],
    }, categoryLabel: 'K-Drama');
    expect(series.type, 'tv');
    expect(series.categories, contains('K-Drama'));
    expect(series.sources, isEmpty);
  });

  test('TMDB search results classify anime and regional drama using metadata', () {
    final anime = MediaContent.fromTmdb({
      'id': 10,
      'media_type': 'tv',
      'name': 'Example Anime',
      'first_air_date': '2023-01-01',
      'original_language': 'ja',
      'origin_country': ['JP'],
      'genre_ids': [16],
    });
    expect(anime.categories, contains('Anime'));

    final koreanDrama = MediaContent.fromTmdb({
      'id': 20,
      'media_type': 'tv',
      'name': 'Example Korean Drama',
      'first_air_date': '2023-01-01',
      'original_language': 'ko',
      'origin_country': ['KR'],
      'genre_ids': [18],
    });
    expect(koreanDrama.categories, contains('Drama'));
    expect(koreanDrama.categories, contains('K-Drama'));

    final indoDrama = MediaContent.fromTmdb({
      'id': 30,
      'media_type': 'tv',
      'name': 'Example Indonesian Drama',
      'first_air_date': '2023-01-01',
      'original_language': 'id',
      'origin_country': ['ID'],
      'genre_ids': [18],
    });
    expect(indoDrama.categories, contains('Indonesian Drama'));
  });

  test('external subtitle metadata is preserved by catalogue serialization', () {
    final content = MediaContent.fromJson({
      'id': 'open-short',
      'title': 'Open Short',
      'type': 'movie',
      'sources': const {},
      'subtitles': {
        'Indonesia': 'https://media.example/subtitles/id.vtt',
        'English': 'https://media.example/subtitles/en.vtt',
      },
    });
    expect(content.subtitles['Indonesia'], 'https://media.example/subtitles/id.vtt');
    final restored = MediaContent.fromJson(content.toJson());
    expect(restored.subtitles, content.subtitles);
    final merged = content.mergeCategories(
      MediaContent.fromJson({
        'id': 'open-short',
        'title': 'Open Short',
        'type': 'movie',
        'sources': const {},
        'categories': ['Drama'],
      }),
    );
    expect(merged.subtitles, content.subtitles);
  });

}
