import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchPage extends StatefulWidget {
  const MatchPage({
    super.key,
    required this.roomId,
    required this.roundId,
    required this.movieId,
  });

  final String roomId;
  final String roundId;
  final String movieId;

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  late final SupabaseClient _client;
  late final ConfettiController _confettiController;
  Map<String, dynamic>? _movie;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    try {
      final rows = await _client
          .from('movies')
          .select('title, overview, source, poster_url, is_netflix, is_cinema, external_id')
          .eq('id', widget.movieId)
          .limit(1);
      if (rows.isNotEmpty) {
        _movie = rows.first;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _confettiController.play();
      }
    }
  }

  Future<void> _logAction(String actionType, String targetUrl) async {
    try {
      await _client.from('action_logs').insert({
        'room_id': widget.roomId,
        'round_id': widget.roundId,
        'user_id': _client.auth.currentUser?.id,
        'movie_id': widget.movieId,
        'action_type': actionType,
        'target_url': targetUrl,
      });
    } catch (_) {}
  }

  Future<void> _openNetflix(String title) async {
    final query = Uri.encodeQueryComponent(title);
    final urlStr = 'https://www.netflix.com/search?q=$query';
    final url = Uri.parse(urlStr);
    await _logAction('watch_netflix', urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Netflix.')),
        );
      }
    }
  }

  Future<void> _openCinema(String title) async {
    final query = Uri.encodeQueryComponent('$title cinema tickets');
    final urlStr = 'https://www.google.com/search?q=$query';
    final url = Uri.parse(urlStr);
    await _logAction('find_cinema', urlStr);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open search.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _movie?['title'] as String? ?? 'Mystery Movie';
    final overview = _movie?['overview'] as String? ??
        'Everyone in your room agreed on this one!';
    final posterUrl = _movie?['poster_url'] as String?;
    final isNetflix = _movie?['is_netflix'] as bool? ?? false;
    final isCinema = _movie?['is_cinema'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF7C4DFF),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.white,
                Color(0xFFFFC72C),
                Color(0xFF22C55E),
                Color(0xFFFF4C7B),
              ],
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    "🎉 IT'S A MATCH!",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Everyone in your group agreed on this movie!',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Movie Poster
                  if (posterUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        posterUrl,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.movie_filter_rounded, size: 80, color: Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.movie_filter_rounded, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  // Info card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101216),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: _isLoading
                        ? const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                overview,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                  // Action buttons based on source
                  if (!_isLoading) ...[
                    if (isNetflix)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openNetflix(title),
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('Watch on Netflix'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    if (isCinema)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openCinema(title),
                          icon: const Icon(Icons.local_movies),
                          label: const Text('Find Cinema Tickets'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC72C),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    if (!isNetflix && !isCinema)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openNetflix(title),
                          icon: const Icon(Icons.search),
                          label: const Text('Search for this movie'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF7C4DFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Back to Room'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


