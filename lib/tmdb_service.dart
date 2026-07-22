import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<Map<String, dynamic>>> fetchTrendingMovies() async {
    final url = Uri.parse('$_baseUrl/trending/movie/day?language=en-US');
    final response = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $tmdbAccessToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>;
      return results.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load TMDB movies: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    if (query.trim().isEmpty) return fetchTrendingMovies();
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = Uri.parse('$_baseUrl/search/movie?query=$encodedQuery&language=en-US');
    final response = await http.get(
      url,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $tmdbAccessToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>;
      return results.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load TMDB movies: ${response.statusCode}');
    }
  }

  static String getPosterUrl(String? posterPath) {
    if (posterPath == null) return '';
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }
}
