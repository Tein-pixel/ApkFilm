import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_content.dart';
import '../services/tmdb_service.dart';

class CatalogRepository {
  CatalogRepository({TmdbService? tmdb}) : _tmdb = tmdb ?? TmdbService();

  final TmdbService _tmdb;
  static const _cacheKey = 'cinewave_tmdb_catalog_v1';
  static const _cacheUpdatedKey = 'cinewave_tmdb_catalog_updated_v1';
  static const _cacheTtl = Duration(hours: 12);

  Future<List<MediaContent>> loadCatalog() async {
    final local = await _loadLocalCatalog();
    if (!_tmdb.isConfigured) return local;

    final cached = await _loadCachedCatalog();
    final prefs = await SharedPreferences.getInstance();
    final lastUpdated = prefs.getInt(_cacheUpdatedKey) ?? 0;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdated;
    final cacheIsFresh = cached.isNotEmpty &&
        lastUpdated > 0 &&
        cacheAge >= 0 &&
        cacheAge < _cacheTtl.inMilliseconds;
    if (cacheIsFresh) return _merge(cached, local);

    final remote = await _tmdb.loadHomeCatalog();
    if (remote.isNotEmpty) {
      final refreshed = _merge(remote, cached);
      await _saveCachedCatalog(refreshed);
      try {
        await prefs.setInt(
          _cacheUpdatedKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {
        // The catalogue remains usable even if its refresh timestamp cannot be saved.
      }
      return _merge(refreshed, local);
    }
    return _merge(cached.isNotEmpty ? cached : local, local);
  }

  Future<List<MediaContent>> searchCatalog(String query, {int page = 1}) async {
    final clean = query.trim();
    if (clean.isEmpty) return loadCatalog();
    if (!_tmdb.isConfigured) {
      final local = await _loadLocalCatalog();
      final q = clean.toLowerCase();
      return local.where((item) => item.title.toLowerCase().contains(q)).toList();
    }
    return _tmdb.searchMulti(clean, page: page);
  }

  Future<Map<String, dynamic>?> getTitleDetails(MediaContent content) =>
      _tmdb.getTitleDetails(content);

  Future<Map<String, dynamic>?> getWatchProviders(MediaContent content) =>
      _tmdb.getWatchProviders(content);

  Future<Map<String, dynamic>?> getTvSeasonDetails(
    MediaContent content,
    int seasonNumber,
  ) => _tmdb.getTvSeasonDetails(content, seasonNumber);

  Future<List<Map<String, dynamic>>> getIndonesiaProviders() =>
      _tmdb.getIndonesiaProviders();

  Future<List<MediaContent>> discoverByProvider(int providerId) =>
      _tmdb.discoverByProvider(providerId);

  Future<List<MediaContent>> _loadLocalCatalog() async {
    final raw = await rootBundle.loadString('assets/database/all_content.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Catalog root must be a JSON array.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => MediaContent.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<MediaContent>> _loadCachedCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final rows = jsonDecode(raw);
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => MediaContent.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCachedCatalog(List<MediaContent> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // Cache failures must not prevent catalogue browsing.
    }
  }

  List<MediaContent> _merge(
    List<MediaContent> first,
    List<MediaContent> second,
  ) {
    final result = <String, MediaContent>{};
    for (final item in [...first, ...second]) {
      final previous = result[item.id];
      result[item.id] =
          previous == null ? item : previous.mergeCategories(item);
    }
    return result.values.toList(growable: false);
  }
}
