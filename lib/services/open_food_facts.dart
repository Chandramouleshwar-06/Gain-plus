import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food.dart';

/// Searches Open Food Facts (openfoodfacts.org), a free, open database of
/// packaged foods. Only the search text is sent.
class OpenFoodFacts {
  final http.Client _client;

  OpenFoodFacts([http.Client? client]) : _client = client ?? http.Client();

  static const _userAgent = 'GainPlus/1.0 (Flutter fitness app)';

  /// Foods matching [query], per serving when the product gives a serving
  /// size, otherwise per 100 g. Products without calories are skipped.
  Future<List<Food>> search(String query) async {
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '25',
      'fields': 'code,product_name,brands,nutriments,serving_size,serving_quantity',
    });
    final response = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw OpenFoodFactsException('Search failed (${response.statusCode})');
    final products = (jsonDecode(response.body) as Map<String, dynamic>)['products'] as List? ?? [];
    return products.whereType<Map>().map(parseProduct).whereType<Food>().toList();
  }

  /// Turns one product into a [Food], or null if it lacks the basics.
  static Food? parseProduct(Map<dynamic, dynamic> p) {
    final code = p['code']?.toString();
    final name = p['product_name'] is String ? (p['product_name'] as String).trim() : null;
    final n = p['nutriments'];
    // Real-world data is messy: anything unexpected skips the product.
    if (code == null || code.isEmpty || name == null || name.isEmpty || n is! Map) return null;

    double? per100(String key) => _num(n['${key}_100g']);
    final kcal100 = per100('energy-kcal') ?? (per100('energy') == null ? null : per100('energy')! / 4.184);
    if (kcal100 == null) return null;

    final grams = _num(p['serving_quantity']);
    final perServing = grams != null && grams > 0 && grams < 2000;
    final factor = perServing ? grams / 100 : 1.0;
    final servingName = perServing ? (p['serving_size'] is String ? p['serving_size'] as String : '${_trim(grams)} g') : '100 g';
    final brand = (p['brands'] is String ? p['brands'] as String : null)?.split(',').first.trim();

    return Food(
      id: 'off-$code',
      name: name,
      brand: brand == null || brand.isEmpty ? null : brand,
      servingName: servingName,
      servingGrams: perServing ? grams : 100,
      kcal: _round(kcal100 * factor),
      protein: _round((per100('proteins') ?? 0) * factor),
      carbs: _round((per100('carbohydrates') ?? 0) * factor),
      fat: _round((per100('fat') ?? 0) * factor),
      source: 'off',
    );
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
  static double _round(double v) => (v * 10).roundToDouble() / 10;
  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class OpenFoodFactsException implements Exception {
  final String message;
  OpenFoodFactsException(this.message);

  @override
  String toString() => message;
}
