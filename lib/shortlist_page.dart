import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShortlistPage extends StatefulWidget {
  const ShortlistPage({super.key});

  @override
  State<ShortlistPage> createState() => _ShortlistPageState();
}

class _ShortlistPageState extends State<ShortlistPage> {
  late final SupabaseClient _client;
  late Future<List<Map<String, dynamic>>> _future;
  RealtimeChannel? _shortlistChannel;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _future = _fetchShortlist();
    _subscribeShortlist();
  }

  void _subscribeShortlist() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _shortlistChannel = _client
        .channel('shortlist_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shortlist_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'shortlist_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _refresh(),
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _shortlistChannel?.unsubscribe();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchShortlist() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    try {
      final data = await _client
          .from('shortlist_items')
          .select('id, expires_at, movie:movies ( id, title, source, poster_url, overview )')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching shortlist: $e');
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchShortlist();
    });
  }

  Future<void> _removeItem(String shortlistId) async {
    try {
      await _client.from('shortlist_items').delete().eq('id', shortlistId);
      await _refresh();
    } catch (e) {
      debugPrint('Error removing shortlist item: $e');
    }
  }

  String _monthAbbr(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shortlist'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading shortlist:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Your shortlist is empty.')),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final shortlistId = item['id'] as String;
                final movie = item['movie'] as Map<String, dynamic>? ?? {};
                final title = movie['title'] as String? ?? 'Untitled';
                final source = movie['source'] as String? ?? '?';
                final posterUrl = movie['poster_url'] as String?;
                final overview = movie['overview'] as String?;
                final expiresAtStr = item['expires_at'] as String?;
                final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
                final daysLeft = expiresAt?.toLocal().difference(DateTime.now()).inDays;
                final expiryLabel = expiresAt != null
                    ? 'Expires ${expiresAt.toLocal().day} ${_monthAbbr(expiresAt.month)} ${expiresAt.year}'
                    : null;
                final expiryColor = daysLeft != null && daysLeft <= 3 ? Colors.amber : Colors.white70;

                  return ListTile(
                    onTap: () {
                      if (overview == null) return;
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(title),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (posterUrl != null)
                                  Image.network(posterUrl, height: 250),
                                const SizedBox(height: 16),
                                Text(overview),
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
                      child: posterUrl != null
                          ? Image.network(posterUrl, fit: BoxFit.cover)
                          : const Icon(Icons.movie, size: 40),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      expiryLabel != null ? '${source.toUpperCase()}  •  $expiryLabel' : source.toUpperCase(),
                      style: TextStyle(color: expiryColor),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove from shortlist',
                      onPressed: () => _removeItem(shortlistId),
                    ),
                  );
                },
              );
          },
        ),
      ),
    );
  }
}


