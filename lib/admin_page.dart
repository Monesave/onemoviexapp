import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0C10),
        appBar: AppBar(
          backgroundColor: const Color(0xFF7C4DFF),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 22),
              SizedBox(width: 8),
              Text(
                'Onemoviex Admin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
              Tab(icon: Icon(Icons.movie_rounded), text: 'Movies'),
              Tab(icon: Icon(Icons.people_rounded), text: 'Users'),
              Tab(icon: Icon(Icons.meeting_room_rounded), text: 'Rooms'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _MoviesTab(),
            _UsersTab(),
            _RoomsTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  int _totalMovies = 0;
  int _netflixMovies = 0;
  int _cinemaMovies = 0;
  int _totalUsers = 0;
  int _subscribers = 0;
  int _activeRooms = 0;
  int _totalSwipes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _client.from('movies').select('id, is_netflix, is_cinema'),
        _client.from('user_profiles').select('id, tier'),
        _client.from('rooms').select('id, status'),
        _client.from('swipes').select('id'),
      ]);

      final movies = results[0] as List;
      final users = results[1] as List;
      final rooms = results[2] as List;
      final swipes = results[3] as List;

      if (mounted) {
        setState(() {
          _totalMovies = movies.length;
          _netflixMovies = movies.where((m) => m['is_netflix'] == true).length;
          _cinemaMovies = movies.where((m) => m['is_cinema'] == true).length;
          _totalUsers = users.length;
          _subscribers = users.where((u) => u['tier'] == 'subscriber').length;
          _activeRooms = rooms.where((r) => r['status'] == 'active').length;
          _totalSwipes = swipes.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pull to refresh',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              children: [
                _StatCard(
                  icon: Icons.movie_rounded,
                  label: 'Total Movies',
                  value: '$_totalMovies',
                  sub: '$_netflixMovies Netflix  ·  $_cinemaMovies Cinema',
                  color: const Color(0xFF7C4DFF),
                ),
                _StatCard(
                  icon: Icons.people_rounded,
                  label: 'Total Users',
                  value: '$_totalUsers',
                  sub: '$_subscribers subscribers',
                  color: const Color(0xFF22C55E),
                ),
                _StatCard(
                  icon: Icons.meeting_room_rounded,
                  label: 'Active Rooms',
                  value: '$_activeRooms',
                  sub: 'rooms in progress',
                  color: const Color(0xFFFFC72C),
                ),
                _StatCard(
                  icon: Icons.swipe_rounded,
                  label: 'Total Swipes',
                  value: '$_totalSwipes',
                  sub: 'all time',
                  color: const Color(0xFFFF4C7B),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BreakdownBar(
                          label: 'Free',
                          count: _totalUsers - _subscribers,
                          total: _totalUsers,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BreakdownBar(
                          label: 'Subscribers',
                          count: _subscribers,
                          total: _totalUsers,
                          color: const Color(0xFF7C4DFF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101216),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOVIES TAB
// ─────────────────────────────────────────────────────────────

class _MoviesTab extends StatefulWidget {
  const _MoviesTab();

  @override
  State<_MoviesTab> createState() => _MoviesTabState();
}

class _MoviesTabState extends State<_MoviesTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _sourceFilter = 'all';

  // Form
  final _titleCtrl = TextEditingController();
  final _overviewCtrl = TextEditingController();
  final _posterCtrl = TextEditingController();
  String _selectedSource = 'netflix';
  String? _editingId;
  bool _showForm = false;
  bool _savingMovie = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _overviewCtrl.dispose();
    _posterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('movies')
          .select('id, title, overview, source, poster_url, is_netflix, is_cinema, created_at')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _movies = List<Map<String, dynamic>>.from(data);
          _applyFilter();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _movies;
    if (_sourceFilter != 'all') {
      list = list.where((m) => m['source'] == _sourceFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((m) {
        final t = (m['title'] as String? ?? '').toLowerCase();
        return t.contains(q);
      }).toList();
    }
    _filtered = list;
  }

  void _openAddForm() {
    setState(() {
      _editingId = null;
      _titleCtrl.clear();
      _overviewCtrl.clear();
      _posterCtrl.clear();
      _selectedSource = 'netflix';
      _showForm = true;
    });
  }

  void _openEditForm(Map<String, dynamic> m) {
    setState(() {
      _editingId = m['id'] as String;
      _titleCtrl.text = m['title'] ?? '';
      _overviewCtrl.text = m['overview'] ?? '';
      _posterCtrl.text = m['poster_url'] ?? '';
      _selectedSource = m['source'] ?? 'netflix';
      _showForm = true;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingId = null;
    });
  }

  Future<void> _uploadImage() async {
    final ({Uint8List? bytes, String? name}) picked;
    try {
      picked = await pickImageBytes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
      return;
    }

    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;

    // Derive a safe extension and MIME type from the file name
    final rawExt = (picked.name?.split('.').last ?? 'jpg').toLowerCase();
    final safeExt = {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(rawExt) ? rawExt : 'jpg';
    final mimeType = safeExt == 'jpg' ? 'image/jpeg' : 'image/$safeExt';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    setState(() => _uploadingImage = true);
    try {
      // Bucket name must match exactly what exists in Supabase Storage.
      const bucket = 'poster bucket';
      await _client.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );
      final url = _client.storage.from(bucket).getPublicUrl(fileName);
      if (mounted) {
        setState(() => _posterCtrl.text = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie title is required.')),
      );
      return;
    }

    setState(() => _savingMovie = true);
    final payload = {
      'title': title,
      'overview': _overviewCtrl.text.trim(),
      'poster_url': _posterCtrl.text.trim().isEmpty ? null : _posterCtrl.text.trim(),
      'source': _selectedSource,
      'is_netflix': _selectedSource == 'netflix',
      'is_cinema': _selectedSource == 'cinema',
    };

    try {
      if (_editingId == null) {
        await _client.from('movies').insert(payload);
      } else {
        await _client.from('movies').update(payload).eq('id', _editingId as Object);
      }
      if (mounted) {
        _closeForm();
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingId == null ? 'Movie added.' : 'Movie updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMovie = false);
    }
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete movie?'),
        content: Text('This will permanently delete "$title".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _client.from('shortlist_items').delete().eq('movie_id', id);
      await _client.from('movies').delete().eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          color: const Color(0xFF101216),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search movies...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _search = v;
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sourceFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'netflix', child: Text('Netflix')),
                  DropdownMenuItem(value: 'cinema', child: Text('Cinema')),
                ],
                onChanged: (v) => setState(() {
                  _sourceFilter = v!;
                  _applyFilter();
                }),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _openAddForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        // Form panel (shown when adding/editing)
        if (_showForm)
          Container(
            color: const Color(0xFF181C24),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _editingId == null ? 'Add New Movie' : 'Edit Movie',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                    IconButton(
                      onPressed: _closeForm,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Movie Title *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _overviewCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Overview / Description',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _posterCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Poster URL',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _uploadingImage ? null : _uploadImage,
                      icon: _uploadingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload, size: 16),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Poster preview
                if (_posterCtrl.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _posterCtrl.text,
                        height: 100,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    const Text('Source: ', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedSource,
                      items: const [
                        DropdownMenuItem(
                          value: 'netflix',
                          child: Row(children: [
                            Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 16),
                            SizedBox(width: 6),
                            Text('Netflix'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'cinema',
                          child: Row(children: [
                            Icon(Icons.local_movies, color: Color(0xFFFFC72C), size: 16),
                            SizedBox(width: 6),
                            Text('Cinema'),
                          ]),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedSource = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingMovie ? null : _save,
                    icon: _savingMovie
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(_editingId == null ? 'Add Movie' : 'Save Changes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        // Movie list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _movies.isEmpty ? 'No movies yet. Tap Add to get started.' : 'No results.',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (context, i) {
                          final m = _filtered[i];
                          final id = m['id'] as String;
                          final title = m['title'] as String? ?? 'Untitled';
                          final posterUrl = m['poster_url'] as String?;
                          final isNetflix = m['is_netflix'] as bool? ?? false;
                          final isCinema = m['is_cinema'] as bool? ?? false;
                          final sourceLabel = isNetflix ? 'Netflix' : isCinema ? 'Cinema' : 'Other';
                          final sourceColor = isNetflix
                              ? const Color(0xFFE50914)
                              : isCinema
                                  ? const Color(0xFFFFC72C)
                                  : Colors.white54;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 60,
                                child: posterUrl != null
                                    ? Image.network(
                                        posterUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.movie, size: 32),
                                      )
                                    : const Icon(Icons.movie, size: 32),
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sourceColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    sourceLabel,
                                    style: TextStyle(
                                      color: sourceColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                  onPressed: () => _openEditForm(m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _delete(id, title),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USERS TAB
// ─────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('user_profiles')
          .select('id, tier, is_admin, created_at')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF101216),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_users.length} users total',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${_users.where((u) => u['tier'] == 'subscriber').length} subscribers',
                  style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('No users found.', style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final id = u['id'] as String? ?? '';
                      final tier = u['tier'] as String? ?? 'free';
                      final isAdmin = u['is_admin'] as bool? ?? false;
                      final createdAt = u['created_at'] as String?;
                      final date = createdAt != null
                          ? DateTime.tryParse(createdAt)?.toLocal()
                          : null;
                      final dateLabel = date != null
                          ? '${date.day} ${_monthAbbr(date.month)} ${date.year}'
                          : '—';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isAdmin
                              ? const Color(0xFFFF4C7B).withValues(alpha: 0.2)
                              : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: isAdmin ? const Color(0xFFFF4C7B) : const Color(0xFF7C4DFF),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          isAdmin ? 'Admin' : 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'ID: ${id.substring(0, 8)}...  ·  Joined $dateLabel',
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tier == 'subscriber'
                                ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: tier == 'subscriber'
                                  ? const Color(0xFF7C4DFF)
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            tier == 'subscriber' ? 'Plus' : 'Free',
                            style: TextStyle(
                              color: tier == 'subscriber' ? const Color(0xFF7C4DFF) : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────
// ROOMS TAB
// ─────────────────────────────────────────────────────────────

class _RoomsTab extends StatefulWidget {
  const _RoomsTab();

  @override
  State<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<_RoomsTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _client
          .from('rooms')
          .select('id, name, status, created_at, owner_id')
          .order('created_at', ascending: false);

      // For each room, fetch participant count
      final rooms = List<Map<String, dynamic>>.from(data);
      final enriched = await Future.wait(rooms.map((r) async {
        final roomId = r['id'] as String;
        final count = await _client
            .from('room_participants')
            .select('id')
            .eq('room_id', roomId);
        return {...r, '_participant_count': (count as List).length};
      }));

      if (mounted) {
        setState(() {
          _rooms = enriched;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF101216),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_rooms.length} rooms total',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${_rooms.where((r) => r['status'] == 'active').length} active',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _rooms.isEmpty
                ? const Center(
                    child: Text('No rooms yet.', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.separated(
                    itemCount: _rooms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, i) {
                      final r = _rooms[i];
                      final name = r['name'] as String? ?? 'Unnamed Room';
                      final status = r['status'] as String? ?? 'unknown';
                      final participantCount = r['_participant_count'] as int? ?? 0;
                      final createdAt = r['created_at'] as String?;
                      final date = createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;
                      final dateLabel = date != null
                          ? '${date.day} ${_monthAbbr(date.month)} ${date.year}'
                          : '—';

                      final isActive = status == 'active';
                      final statusColor = isActive ? const Color(0xFF22C55E) : Colors.white38;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFC72C).withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.meeting_room_rounded,
                            color: Color(0xFFFFC72C),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$participantCount participants  ·  Created $dateLabel',
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}
