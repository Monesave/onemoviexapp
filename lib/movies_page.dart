import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _allMovies = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<String> _shortlistedIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  RealtimeChannel? _shortlistChannel;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _loadAll();
    _subscribeShortlist();
  }

  @override
  void dispose() {
    _shortlistChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeShortlist() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _shortlistChannel = _client
        .channel('shortlist_realtime_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shortlist_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final movieId = payload.newRecord['movie_id'] as String?;
            if (movieId != null && mounted) {
              setState(() => _shortlistedIds.add(movieId));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'shortlist_items',
          callback: (payload) {
            final movieId = payload.oldRecord['movie_id'] as String?;
            if (movieId != null && mounted) {
              setState(() => _shortlistedIds.remove(movieId));
            }
          },
        )
        ..subscribe();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchMovies(), _loadShortlist()]);
  }

  Future<void> _fetchMovies() async {
    try {
      final data = await _client
          .from('movies')
          .select('id, title, overview, poster_url, source, is_netflix, is_cinema')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _allMovies = List<Map<String, dynamic>>.from(data);
          _applySearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) {
      _filtered = List.from(_allMovies);
    } else {
      _filtered = _allMovies
          .where((m) =>
              (m['title'] as String? ?? '').toLowerCase().contains(q) ||
              (m['overview'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
  }

  Future<void> _loadShortlist() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _client
          .from('shortlist_items')
          .select('movie_id')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _shortlistedIds
            ..clear()
            ..addAll(data.map<String>((r) => r['movie_id'] as String));
        });
      }
    } catch (e) {
      debugPrint('Error loading shortlist IDs: $e');
    }
  }

  Future<void> _toggleShortlist(Map<String, dynamic> movie) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final movieId = movie['id'] as String;
    final isShortlisted = _shortlistedIds.contains(movieId);

    try {
      if (isShortlisted) {
        await _client
            .from('shortlist_items')
            .delete()
            .match({'user_id': userId, 'movie_id': movieId});
      } else {
        await _client.from('shortlist_items').upsert({
          'user_id': userId,
          'movie_id': movieId,
        });
      }
      await _loadShortlist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating shortlist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search movies...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
            prefixIcon: Icon(Icons.search, color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              _applySearch();
            });
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _applySearch();
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: _filtered.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.movie_outlined, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No movies yet.\nAsk your admin to add some!'
                                    : 'No movies found for "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final movie = _filtered[index];
                        final title = movie['title'] as String? ?? 'Untitled';
                        final posterUrl = movie['poster_url'] as String?;
                        final overview = movie['overview'] as String? ?? '';
                        final isNetflix = movie['is_netflix'] as bool? ?? false;
                        final isCinema = movie['is_cinema'] as bool? ?? false;
                        final movieId = movie['id'] as String;
                        final isShortlisted = _shortlistedIds.contains(movieId);

                        return ListTile(
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(title),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (posterUrl != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(posterUrl, height: 250,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.movie, size: 80)),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          if (isNetflix)
                                            const Chip(
                                              label: Text('Netflix', style: TextStyle(fontSize: 11)),
                                              avatar: Icon(Icons.play_circle_fill,
                                                  color: Color(0xFFE50914), size: 16),
                                              backgroundColor: Color(0x26E50914),
                                            ),
                                          if (isCinema)
                                            const Chip(
                                              label: Text('Cinema', style: TextStyle(fontSize: 11)),
                                              avatar: Icon(Icons.local_movies,
                                                  color: Color(0xFFFFC72C), size: 16),
                                              backgroundColor: Color(0x26FFC72C),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (overview.isNotEmpty) Text(overview),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          leading: SizedBox(
                            width: 50,
                            height: 70,
                            child: posterUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      posterUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.movie, size: 40),
                                    ),
                                  )
                                : const Icon(Icons.movie, size: 40),
                          ),
                          title: Text(title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isNetflix) ...[
                                    const Icon(Icons.play_circle_fill,
                                        size: 12, color: Color(0xFFE50914)),
                                    const SizedBox(width: 3),
                                    const Text('Netflix',
                                        style: TextStyle(
                                            fontSize: 11, color: Color(0xFFE50914))),
                                    const SizedBox(width: 8),
                                  ],
                                  if (isCinema) ...[
                                    const Icon(Icons.local_movies,
                                        size: 12, color: Color(0xFFFFC72C)),
                                    const SizedBox(width: 3),
                                    const Text('Cinema',
                                        style: TextStyle(
                                            fontSize: 11, color: Color(0xFFFFC72C))),
                                  ],
                                ],
                              ),
                              if (overview.isNotEmpty)
                                Text(
                                  overview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
                          isThreeLine: overview.isNotEmpty,
                          trailing: IconButton(
                            icon: Icon(
                              isShortlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border_outlined,
                              color: isShortlisted ? Colors.pinkAccent : Colors.white70,
                            ),
                            tooltip: isShortlisted
                                ? 'Remove from shortlist'
                                : 'Add to shortlist',
                            onPressed: () => _toggleShortlist(movie),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
