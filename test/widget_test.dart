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
}
