import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/media_content.dart';

class CatalogRepository {
  Future<List<MediaContent>> loadCatalog() async {
    final raw = await rootBundle.loadString('assets/database/all_content.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List)
      throw const FormatException('Catalog root must be a JSON array.');
    return decoded
        .whereType<Map>()
        .map((item) => MediaContent.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  }
}
